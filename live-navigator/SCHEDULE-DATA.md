# Delhi Metro scheduled arrivals

Live Navigator uses the archived DMRC static GTFS snapshot distributed with the MetroShell v1.0.0 public release. The source feed is listed by Delhi Open Transit Data as the DMRC static dataset, last updated 10 August 2023. It contains station stop times and trip records for weekday, Saturday, and Sunday service patterns.

Train markers are filtered to the lines in a planned Metro route. Without a planned route, Live Navigator uses GPS to find the nearest Metro station (within 1.5 km) and shows its serving lines. The map highlights the next train scheduled to arrive at that station and estimates the wait from the timetable.

The app presents the selected station's next scheduled arrival and departure calls, route, and trip destination. Train markers interpolate along the archived GTFS route shapes between scheduled stops, using the schedule clock for movement and dwell time. This archive contains Saturday trips only for the Red Line and no Sunday trips. To show service across the other lines on weekends, the animation uses the archived weekday pattern for lines with no weekend trips; the map labels this as a weekday preview. The GTFS calendar in this snapshot ends on 31 December 2025, so this prototype repeats day patterns by weekday. It does not account for public holidays, service changes, delays, or current train positions. Animated positions are estimates derived from the historical schedule, not live telemetry.

Sources: [OTD DMRC Static Data](https://otd.delhi.gov.in/data/staticDMRC/) · [MetroShell public GTFS snapshot release](https://github.com/adot-7/metroshell/releases/tag/v1.0.0)
