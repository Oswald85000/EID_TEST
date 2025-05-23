from flask import Flask, request, jsonify
from prometheus_client import Gauge, generate_latest, REGISTRY
import ctypes

# ------------------------------------------------------------------ #
# Bibliothèque C : /app/libeid.so (compilée dans le Dockerfile)
lib = ctypes.CDLL("/app/libeid.so")
lib.eid_update.restype = ctypes.c_float

class Ctx(ctypes.Structure):
    _fields_ = [
        ("alpha", ctypes.c_float),
        ("beta",  ctypes.c_float),
        ("gamma", ctypes.c_float),
        ("delta", ctypes.c_float),
    ]

ctx = Ctx(1.2, 1.0, 0.05, 0.01)          # α β γ δ par défaut

# ------------------------------------------------------------------ #
# Métriques Prometheus
g_mu    = Gauge("eid_mu",    "Mu = alpha / beta")
g_dHdt  = Gauge("eid_dHdt",  "Entropic derivative dH/dt")
g_alarm = Gauge("eid_alarm", "Alarm (1 if mu < 1)")

# ------------------------------------------------------------------ #
app = Flask(__name__)

@app.route("/update", methods=["POST"])
def update():
    """Calcul dH/dt + mise à jour des métriques"""
    data = request.get_json() or {}
    H = float(data.get("H", 1.0))
    F = float(data.get("F", 0.1))
    O = float(data.get("O", 0.0))

    alarm = ctypes.c_bool()
    dHdt  = lib.eid_update(
        ctypes.byref(ctx),
        ctypes.c_float(H), ctypes.c_float(F), ctypes.c_float(O),
        ctypes.byref(alarm)
    )

    mu = ctx.alpha / ctx.beta
    g_mu.set(mu); g_dHdt.set(dHdt); g_alarm.set(int(alarm.value))
    return jsonify(dHdt=dHdt, mu=mu, alarm=bool(alarm.value))

@app.route("/coeffs", methods=["POST"])
def set_coeffs():
    """Change α β γ δ à chaud"""
    data = request.get_json() or {}
    ctx.alpha = float(data.get("alpha", ctx.alpha))
    ctx.beta  = float(data.get("beta",  ctx.beta))
    ctx.gamma = float(data.get("gamma", ctx.gamma))
    ctx.delta = float(data.get("delta", ctx.delta))
    return jsonify(alpha=ctx.alpha, beta=ctx.beta,
                   gamma=ctx.gamma, delta=ctx.delta)

@app.route("/metrics")
def metrics():
    """Endpoint Prometheus"""
    return generate_latest(REGISTRY), 200, {"Content-Type": "text/plain"}

# ------------------------------------------------------------------ #
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
