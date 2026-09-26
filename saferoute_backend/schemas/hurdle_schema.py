from typing import List, Optional
from pydantic import BaseModel

class HurdleCreate(BaseModel):
    lat: float
    lng: float
    hurdle_type: str
    description: str

class HurdleUpdate(BaseModel):
    hurdle_type: Optional[str] = None
    description: Optional[str] = None

class VoteRequest(BaseModel):
    is_active: bool

class Coordinate(BaseModel):
    lat: float
    lng: float

class RouteCheckRequest(BaseModel):
    route: List[Coordinate]