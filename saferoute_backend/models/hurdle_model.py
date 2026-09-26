from sqlalchemy import Column, Integer, String
from geoalchemy2 import Geometry
from map_database import Base

class HurdleDB(Base):
    __tablename__ = "road_hurdles"
    
    id = Column(Integer, primary_key=True, index=True)
    hurdle_type = Column(String, index=True)
    description = Column(String)
    reliability_score = Column(Integer, default=0)
    location = Column(Geometry(geometry_type="POINT", srid=4326))