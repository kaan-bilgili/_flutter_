from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.db import insert_relay_log, get_relay_logs

router = APIRouter(prefix="/commands", tags=["commands"])


class CommandCreate(BaseModel):
    state: str
    triggered_by: str

class SetpointCommand(BaseModel):
    setpoint: float

@router.post("/setpoint")
def update_setpoint(command: SetpointCommand):
    try:
        # Here you can add logic to send this setpoint to your thermostat
        print(f"New setpoint received: {command.setpoint}")
        return {"message": "Setpoint updated", "setpoint": command.setpoint}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/")
def create_command(command: CommandCreate):
    try:
        state = command.state.lower()

        if state not in ["on", "off"]:
            raise HTTPException(
                status_code=400,
                detail="Invalid state. Allowed values are 'on' or 'off'."
            )

        saved_log = insert_relay_log(
            state=state,
            triggered_by=command.triggered_by
        )

        return {
            "message": "Command received successfully",
            "data": saved_log
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process command: {str(e)}"
        )


@router.get("/")
def read_commands(limit: int = 50):
    try:
        logs = get_relay_logs(limit=limit)
        return {
            "count": len(logs),
            "data": logs
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch command logs: {str(e)}"
        )
