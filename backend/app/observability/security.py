import structlog

_sec_log = structlog.get_logger("security")


def log_security_event(
    event: str,
    ip: str,
    user_id: str | None = None,
    detail: str = "",
) -> None:
    """
    Emit a structured security event to the log stream.

    Args:
        event: One of "auth.failure", "auth.success", "permission.denied", "anomaly.brute_force"
        ip: Source IP address
        user_id: Authenticated user ID if known
        detail: Additional context (e.g. failure reason)
    """
    _sec_log.warning(
        "security.event",
        event=event,
        user_id=user_id,
        ip=ip,
        detail=detail,
    )

    if event == "auth.failure":
        from app.observability.metrics import security_auth_failures_total
        security_auth_failures_total.add(1, {"ip": ip})
