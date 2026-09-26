from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, text
from map_database import get_db
from models.hurdle_model import HurdleDB
from schemas.hurdle_schema import HurdleCreate, VoteRequest, RouteCheckRequest, HurdleUpdate

router = APIRouter(prefix="/api/complaints", tags=["Complaints and Maps"])

@router.post("/")
def create_hurdle(hurdle: HurdleCreate, db: Session = Depends(get_db)):
    point_wkt = f"SRID=4326;POINT({hurdle.lng} {hurdle.lat})"
    db_hurdle = HurdleDB(
        hurdle_type=hurdle.hurdle_type,
        description=hurdle.description,
        reliability_score=0,
        location=point_wkt
    )
    db.add(db_hurdle)
    db.commit()
    return {"status": "success", "message": "Hurdle permanently anchored to the map."}


@router.put("/{hurdle_id}")
def update_hurdle(hurdle_id: int, update_data: HurdleUpdate, db: Session = Depends(get_db)):
    # Find the existing map marker
    hurdle = db.query(HurdleDB).filter(HurdleDB.id == hurdle_id).first()
    
    if not hurdle:
        raise HTTPException(status_code=404, detail="Hurdle not found upon the map.")
    
    # Apply the requested changes
    if update_data.hurdle_type is not None:
        hurdle.hurdle_type = update_data.hurdle_type
    if update_data.description is not None:
        hurdle.description = update_data.description
        
    db.commit()
    db.refresh(hurdle)
    
    return {"status": "success", "message": "Map marker successfully altered."}


@router.get("/area")
def get_hurdles_in_area(min_lat: float, min_lng: float, max_lat: float, max_lng: float, db: Session = Depends(get_db)):
    bounding_box = func.ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
    hurdles = db.query(HurdleDB).filter(func.ST_Intersects(HurdleDB.location, bounding_box)).all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": h.id,
                "type": h.hurdle_type,
                "description": h.description,
                "reliabilityScore": h.reliability_score,
                "latitude": db.scalar(func.ST_Y(h.location)),
                "longitude": db.scalar(func.ST_X(h.location))
            } for h in hurdles
        ]
    }

@router.post("/{hurdle_id}/vote")
def vote_hurdle(hurdle_id: int, vote: VoteRequest, db: Session = Depends(get_db)):
    hurdle = db.query(HurdleDB).filter(HurdleDB.id == hurdle_id).first()
    if not hurdle:
        raise HTTPException(status_code=404, detail="Hurdle not found")
    
    hurdle.reliability_score += 1 if vote.is_active else -1
    
    if hurdle.reliability_score <= -5:
        db.delete(hurdle)
        db.commit()
        return {"status": "success", "message": "Hurdle resolved and removed from map."}
        
    db.commit()
    return {"status": "success", "new_score": hurdle.reliability_score}

@router.post("/check-route")
def check_route_safety(request: RouteCheckRequest, db: Session = Depends(get_db)):
    if len(request.route) < 2:
        raise HTTPException(status_code=400, detail="A route must possess at least a start and end point.")
        
    # Convert the JSON coordinate list into a PostGIS LINESTRING format
    points = ", ".join([f"{coord.lng} {coord.lat}" for coord in request.route])
    linestring = f"LINESTRING({points})"
    
    query = text("""
        SELECT id, hurdle_type, description, reliability_score, 
               ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat
        FROM road_hurdles
        WHERE ST_DWithin(
            location::geography, 
            ST_GeomFromText(:linestring, 4326)::geography, 
            15
        )
        AND reliability_score > -5
    """)
    
    # In SQLAlchemy 2.0, use the mappings() function to safely access row data by string keys
    result = db.execute(query, {"linestring": linestring}).mappings().all()
    
    return {
        "status": "success",
        "hazards_found": len(result),
        "data": [
            {
                "id": row["id"],
                "type": row["hurdle_type"],
                "description": row["description"],
                "reliabilityScore": row["reliability_score"],
                "latitude": row["lat"],
                "longitude": row["lng"]
            } for row in result
        ]
    }