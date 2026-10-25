import logging
from typing import Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, Field

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger("infra-ops")

app = FastAPI(title="AI Infrastructure Operations", version="0.1.0")


class AlertRecord(BaseModel):
    status: str = "unknown"
    labels: Dict[str, str] = Field(default_factory=dict)
    annotations: Dict[str, str] = Field(default_factory=dict)
    startsAt: Optional[str] = None
    endsAt: Optional[str] = None
    generatorURL: Optional[str] = None
    fingerprint: Optional[str] = None


class AlertmanagerPayload(BaseModel):
    receiver: Optional[str] = None
    status: str = "unknown"
    alerts: List[AlertRecord] = Field(default_factory=list)
    groupLabels: Dict[str, str] = Field(default_factory=dict)
    commonLabels: Dict[str, str] = Field(default_factory=dict)
    commonAnnotations: Dict[str, str] = Field(default_factory=dict)
    externalURL: Optional[str] = None
    version: Optional[str] = None
    groupKey: Optional[str] = None


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/webhook/alertmanager")
def receive_alert(payload: AlertmanagerPayload):
    for alert in payload.alerts:
        logger.info(
            "Alert received: name=%s status=%s severity=%s instance=%s summary=%s",
            alert.labels.get("alertname", "unknown"),
            alert.status,
            alert.labels.get("severity", "unspecified"),
            alert.labels.get("instance", "unknown"),
            alert.annotations.get("summary", "No summary provided"),
        )

    return {
        "status": "accepted",
        "notification_status": payload.status,
        "alerts_received": len(payload.alerts),
    }
