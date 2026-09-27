import json
import urllib.request
import math

# We will generate a much larger set of stations for major lines (Yellow, Blue, Magenta, Red, Violet, Airport).
# Since querying overpass and formatting perfectly is error-prone in one shot, 
# I will procedurally generate realistic stations along these lines based on bounding boxes 
# and real major stations to fill out the map realistically for the prototype, 
# or use a predefined list of real stations. 

lines = {
    'Yellow': {'id': 'delhi_yellow', 'color': '#FACC15', 'stations': [
        ('Samaypur Badli', 28.7460, 77.1352), ('Rohini Sector 18, 19', 28.7381, 77.1491), ('Haiderpur Badli Mor', 28.7303, 77.1561), ('Jahangirpuri', 28.7259, 77.1643), ('Adarsh Nagar', 28.7159, 77.1706), ('Azadpur', 28.7067, 77.1812), ('Model Town', 28.7025, 77.1843), ('GTB Nagar', 28.6974, 77.1994), ('Vishwavidyalaya', 28.6941, 77.2064), ('Vidhan Sabha', 28.6775, 77.2148), ('Civil Lines', 28.6756, 77.2255), ('Kashmere Gate', 28.6675, 77.2285), ('Chandni Chowk', 28.6578, 77.2301), ('Chawri Bazar', 28.6496, 77.2263), ('New Delhi', 28.6431, 77.2223), ('Rajiv Chowk', 28.6328, 77.2197), ('Patel Chowk', 28.6232, 77.2133), ('Central Secretariat', 28.6146, 77.2119), ('Udyog Bhawan', 28.6119, 77.2120), ('Lok Kalyan Marg', 28.5982, 77.2078), ('Jor Bagh', 28.5866, 77.2079), ('INA', 28.5759, 77.2079), ('AIIMS', 28.5684, 77.2076), ('Green Park', 28.5583, 77.2067), ('Hauz Khas', 28.5431, 77.2065), ('Malviya Nagar', 28.5282, 77.2064), ('Saket', 28.5202, 77.2016), ('Qutab Minar', 28.5250, 77.1856), ('Chhatarpur', 28.5065, 77.1751), ('Sultanpur', 28.4981, 77.1585), ('Ghitorni', 28.4913, 77.1444), ('Arjan Garh', 28.4806, 77.1260), ('Guru Dronacharya', 28.4820, 77.1009), ('Sikandarpur', 28.4818, 77.0928), ('MG Road', 28.4795, 77.0792), ('IFFCO Chowk', 28.4722, 77.0717), ('Millennium City Centre', 28.4593, 77.0725)
    ]},
    'Blue': {'id': 'delhi_blue', 'color': '#2563EB', 'stations': [
        ('Dwarka Sector 21', 28.5522, 77.0583), ('Dwarka Sector 8', 28.5615, 77.0520), ('Dwarka Sector 9', 28.5714, 77.0425), ('Dwarka Sector 10', 28.5796, 77.0345), ('Dwarka Sector 11', 28.5872, 77.0270), ('Dwarka Sector 12', 28.5925, 77.0308), ('Dwarka Sector 13', 28.5976, 77.0336), ('Dwarka Sector 14', 28.6027, 77.0256), ('Dwarka', 28.6111, 77.0177), ('Dwarka Mor', 28.6190, 77.0245), ('Nawada', 28.6202, 77.0436), ('Uttam Nagar West', 28.6219, 77.0569), ('Uttam Nagar East', 28.6231, 77.0652), ('Janakpuri West', 28.6294, 77.0782), ('Janakpuri East', 28.6346, 77.0854), ('Tilak Nagar', 28.6369, 77.0954), ('Subhash Nagar', 28.6401, 77.1051), ('Tagore Garden', 28.6429, 77.1132), ('Rajouri Garden', 28.6476, 77.1218), ('Ramesh Nagar', 28.6508, 77.1325), ('Moti Nagar', 28.6575, 77.1420), ('Kirti Nagar', 28.6558, 77.1481), ('Shadipur', 28.6521, 77.1578), ('Patel Nagar', 28.6480, 77.1687), ('Rajendra Place', 28.6437, 77.1774), ('Karol Bagh', 28.6441, 77.1901), ('Jhandewalan', 28.6444, 77.2001), ('RK Ashram Marg', 28.6391, 77.2091), ('Rajiv Chowk', 28.6328, 77.2197), ('Barakhamba Road', 28.6310, 77.2272), ('Mandi House', 28.6258, 77.2343), ('Supreme Court', 28.6232, 77.2435), ('Indraprastha', 28.6210, 77.2519), ('Yamuna Bank', 28.6210, 77.2642), ('Akshardham', 28.6171, 77.2796), ('Mayur Vihar 1', 28.6044, 77.2946), ('Mayur Vihar Ext', 28.5960, 77.3006), ('New Ashok Nagar', 28.5872, 77.3117), ('Noida Sector 15', 28.5843, 77.3155), ('Noida Sector 16', 28.5778, 77.3175), ('Noida Sector 18', 28.5707, 77.3204), ('Botanical Garden', 28.5645, 77.3342), ('Golf Course', 28.5670, 77.3450), ('Noida City Centre', 28.5746, 77.3561), ('Noida Sector 34', 28.5822, 77.3621), ('Noida Sector 52', 28.5912, 77.3653), ('Noida Sector 61', 28.5969, 77.3670), ('Noida Sector 59', 28.6062, 77.3678), ('Noida Sector 62', 28.6133, 77.3688), ('Noida Electronic City', 28.6277, 77.3732)
    ]},
    'Red': {'id': 'delhi_red', 'color': '#DC2626', 'stations': [
        ('Rithala', 28.7208, 77.1072), ('Rohini West', 28.7153, 77.1143), ('Rohini East', 28.7126, 77.1235), ('Pitampura', 28.6987, 77.1352), ('Kohat Enclave', 28.6943, 77.1423), ('Netaji Subhash Place', 28.6953, 77.1517), ('Keshav Puram', 28.6908, 77.1611), ('Kanhaiya Nagar', 28.6823, 77.1685), ('Inderlok', 28.6732, 77.1706), ('Shastri Nagar', 28.6710, 77.1812), ('Pratap Nagar', 28.6675, 77.1950), ('Tis Hazari', 28.6656, 77.2140), ('Kashmere Gate', 28.6675, 77.2285), ('Shastri Park', 28.6685, 77.2477), ('Seelampur', 28.6644, 77.2652), ('Welcome', 28.6715, 77.2778), ('Shahdara', 28.6750, 77.2889), ('Mansarovar Park', 28.6830, 77.2995), ('Jhilmil', 28.6872, 77.3101), ('Dilshad Garden', 28.6831, 77.3213), ('Shaheed Nagar', 28.6806, 77.3321), ('Raj Bagh', 28.6823, 77.3456), ('Major Mohit Sharma', 28.6845, 77.3602), ('Shyam Park', 28.6865, 77.3756), ('Mohan Nagar', 28.6820, 77.3912), ('Arthala', 28.6782, 77.4067), ('Hindon River', 28.6745, 77.4150), ('Shaheed Sthal', 28.6710, 77.4243)
    ]},
    'Magenta': {'id': 'delhi_magenta', 'color': '#D946EF', 'stations': [
        ('Janakpuri West', 28.6294, 77.0782), ('Dabri Mor', 28.6145, 77.0856), ('Dashrath Puri', 28.6012, 77.0867), ('Palam', 28.5910, 77.0845), ('Sadar Bazar Cantonment', 28.5815, 77.0988), ('Terminal 1 IGI Airport', 28.5583, 77.0988), ('Shankar Vihar', 28.5490, 77.1189), ('Vasant Vihar', 28.5576, 77.1593), ('Munirka', 28.5555, 77.1724), ('RK Puram', 28.5534, 77.1835), ('IIT Delhi', 28.5463, 77.1945), ('Hauz Khas', 28.5431, 77.2065), ('Panchsheel Park', 28.5413, 77.2186), ('Chirag Delhi', 28.5401, 77.2307), ('Greater Kailash', 28.5365, 77.2415), ('Nehru Enclave', 28.5412, 77.2520), ('Kalkaji Mandir', 28.5492, 77.2588), ('Okhla NSIC', 28.5552, 77.2649), ('Sukhdev Vihar', 28.5621, 77.2766), ('Jamia Millia Islamia', 28.5615, 77.2858), ('Okhla Vihar', 28.5543, 77.2965), ('Jasola Vihar Shaheen Bagh', 28.5471, 77.3076), ('Kalindi Kunj', 28.5435, 77.3190), ('Okhla Bird Sanctuary', 28.5534, 77.3245), ('Botanical Garden', 28.5645, 77.3342)
    ]},
    'Violet': {'id': 'delhi_violet', 'color': '#7C3AED', 'stations': [
        ('Kashmere Gate', 28.6675, 77.2285), ('Lal Quila', 28.6548, 77.2393), ('Jama Masjid', 28.6481, 77.2346), ('Delhi Gate', 28.6416, 77.2398), ('ITO', 28.6297, 77.2414), ('Mandi House', 28.6258, 77.2343), ('Janpath', 28.6257, 77.2198), ('Central Secretariat', 28.6146, 77.2119), ('Khan Market', 28.6015, 77.2272), ('JLN Stadium', 28.5854, 77.2338), ('Jangpura', 28.5815, 77.2435), ('Lajpat Nagar', 28.5714, 77.2372), ('Moolchand', 28.5639, 77.2355), ('Kailash Colony', 28.5546, 77.2417), ('Nehru Place', 28.5478, 77.2514), ('Kalkaji Mandir', 28.5492, 77.2588), ('Govind Puri', 28.5367, 77.2655), ('Harkesh Nagar', 28.5332, 77.2755), ('Jasola Apollo', 28.5256, 77.2831), ('Sarita Vihar', 28.5147, 77.2907), ('Mohan Estate', 28.5028, 77.2989), ('Tughlakabad', 28.4905, 77.3069), ('Badarpur Border', 28.4936, 77.3117), ('Sarai', 28.4735, 77.3146), ('NHPC Chowk', 28.4618, 77.3159), ('Mewala Maharajpur', 28.4502, 77.3175), ('Sector 28', 28.4385, 77.3190), ('Badkal Mor', 28.4258, 77.3195), ('Old Faridabad', 28.4116, 77.3197), ('Neelam Chowk', 28.3982, 77.3201), ('Bata Chowk', 28.3845, 77.3204), ('Escorts Mujesar', 28.3712, 77.3207), ('Sant Surdas', 28.3585, 77.3210), ('Raja Nahar Singh', 28.3458, 77.3213)
    ]},
    'Airport': {'id': 'delhi_airport', 'color': '#EA580C', 'stations': [
        ('New Delhi', 28.6431, 77.2223), ('Shivaji Stadium', 28.6310, 77.2144), ('Dhaula Kuan', 28.5919, 77.1624), ('Delhi Aerocity', 28.5511, 77.1224), ('IGI Airport', 28.5562, 77.0858), ('Dwarka Sector 21', 28.5522, 77.0583), ('Yashobhoomi Dwarka Sec 25', 28.5385, 77.0423)
    ]}
}

dart_code = """import '../models/station.dart';
import '../models/transit_line.dart';
import '../graph/transit_graph.dart';

class DelhiMetroSeed {
  static const String city = 'Delhi';

"""

for lname, ldata in lines.items():
    dart_code += f"  static const TransitLine {lname.lower()}Line = TransitLine(id: '{ldata['id']}', name: '{lname} Line', city: city, colorHex: '{ldata['color']}', code: '{lname[:2].upper()}');\n"

dart_code += "\n  static void populate(TransitGraph graph) {\n"

for lname, ldata in lines.items():
    dart_code += f"    graph.addLine({lname.lower()}Line);\n"

dart_code += "\n"

# deduplicate stations
stations_map = {}
for lname, ldata in lines.items():
    for (sname, lat, lon) in ldata['stations']:
        sid = 'delhi_' + sname.lower().replace(' ', '_').replace(',', '')
        if sid not in stations_map:
            stations_map[sid] = {
                'id': sid,
                'name': sname,
                'lat': lat,
                'lon': lon,
                'lines': [ldata['id']]
            }
        else:
            if ldata['id'] not in stations_map[sid]['lines']:
                stations_map[sid]['lines'].append(ldata['id'])

for sid, sdata in stations_map.items():
    line_ids_str = ", ".join([f"'{lid}'" for lid in sdata['lines']])
    is_interchange = "true" if len(sdata['lines']) > 1 else "false"
    dart_code += f"    graph.addStation(const Station(id: '{sid}', name: '{sdata['name']}', city: city, latitude: {sdata['lat']}, longitude: {sdata['lon']}, lineIds: [{line_ids_str}], isInterchange: {is_interchange}));\n"

dart_code += "\n"

for lname, ldata in lines.items():
    stations = ldata['stations']
    for i in range(len(stations)-1):
        s1id = 'delhi_' + stations[i][0].lower().replace(' ', '_').replace(',', '')
        s2id = 'delhi_' + stations[i+1][0].lower().replace(' ', '_').replace(',', '')
        # distance in meters roughly
        import math
        def haversine(lat1, lon1, lat2, lon2):
            R = 6371000
            phi1, phi2 = math.radians(lat1), math.radians(lat2)
            dphi = math.radians(lat2 - lat1)
            dlam = math.radians(lon2 - lon1)
            a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
            return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        dist = haversine(stations[i][1], stations[i][2], stations[i+1][1], stations[i+1][2])
        time_sec = int(dist / 12.0) + 30 # approx 12 m/s + 30s stop
        dart_code += f"    graph.addBidirectionalRailEdge(from: graph.stations['{s1id}']!, to: graph.stations['{s2id}']!, lineId: '{ldata['id']}', travelTimeSeconds: {time_sec});\n"

dart_code += "  }\n}\n"

with open('lib/data/delhi_metro_seed.dart', 'w') as f:
    f.write(dart_code)

print("Created seed with ~200 stations")
