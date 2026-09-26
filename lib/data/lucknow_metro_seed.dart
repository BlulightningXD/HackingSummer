import '../models/station.dart';
import '../models/transit_line.dart';
import '../graph/transit_graph.dart';

class LucknowMetroSeed {
  static const String city = 'Lucknow';

  static const TransitLine redLine = TransitLine(
    id: 'lucknow_red',
    name: 'Red Line (North-South Corridor)',
    city: city,
    colorHex: '#EF4444', // Red
    code: 'LMR',
  );

  static void populate(TransitGraph graph) {
    graph.addLine(redLine);

    final stations = [
      const Station(
        id: 'lko_ccs_airport',
        name: 'Chaudhary Charan Singh International Airport',
        hindiName: 'चौधरी चरण सिंह हवाई अड्डा',
        city: city,
        latitude: 26.7645,
        longitude: 80.8842,
        lineIds: ['lucknow_red'],
        undergroundDepthLevel: 1,
        isDeadzone: true,
      ),
      const Station(
        id: 'lko_amausi',
        name: 'Amausi',
        hindiName: 'अमौसी',
        city: city,
        latitude: 26.7725,
        longitude: 80.8885,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_transport_nagar',
        name: 'Transport Nagar',
        hindiName: 'ट्रांसपोर्ट नगर',
        city: city,
        latitude: 26.7820,
        longitude: 80.8930,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_krishna_nagar',
        name: 'Krishna Nagar',
        hindiName: 'कृष्णा नगर',
        city: city,
        latitude: 26.7935,
        longitude: 80.8972,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_singar_nagar',
        name: 'Singar Nagar',
        hindiName: 'सिंगार नगर',
        city: city,
        latitude: 26.8021,
        longitude: 80.9015,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_alambagh',
        name: 'Alambagh',
        hindiName: 'आलमबाग़',
        city: city,
        latitude: 26.8115,
        longitude: 80.9062,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_alambagh_bus_stn',
        name: 'Alambagh Bus Station',
        hindiName: 'आलमबाग़ बस स्टेशन',
        city: city,
        latitude: 26.8180,
        longitude: 80.9105,
        lineIds: ['lucknow_red'],
        isInterchange: true,
      ),
      const Station(
        id: 'lko_mawaiya',
        name: 'Mawaiya',
        hindiName: 'मवैया',
        city: city,
        latitude: 26.8245,
        longitude: 80.9140,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_durgapuri',
        name: 'Durgapuri',
        hindiName: 'दुर्गापुरी',
        city: city,
        latitude: 26.8290,
        longitude: 80.9175,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_charbagh',
        name: 'Charbagh Railway Station',
        hindiName: 'चारबाग़ रेलवे स्टेशन',
        city: city,
        latitude: 26.8325,
        longitude: 80.9220,
        lineIds: ['lucknow_red'],
        isInterchange: true,
      ),
      const Station(
        id: 'lko_hussainganj',
        name: 'Hussainganj',
        hindiName: 'हुसैनगंज',
        city: city,
        latitude: 26.8402,
        longitude: 80.9285,
        lineIds: ['lucknow_red'],
        undergroundDepthLevel: 2,
        isDeadzone: true, // Subterranean section
      ),
      const Station(
        id: 'lko_sachivalaya',
        name: 'Sachivalaya',
        hindiName: 'सचिवालय',
        city: city,
        latitude: 26.8458,
        longitude: 80.9332,
        lineIds: ['lucknow_red'],
        undergroundDepthLevel: 2,
        isDeadzone: true, // Subterranean section
      ),
      const Station(
        id: 'lko_hazratganj',
        name: 'Hazratganj',
        hindiName: 'हज़रतगंज',
        city: city,
        latitude: 26.8520,
        longitude: 80.9390,
        lineIds: ['lucknow_red'],
        undergroundDepthLevel: 2,
        isDeadzone: true, // Subterranean section in prime downtown
      ),
      const Station(
        id: 'lko_kd_singh_stadium',
        name: 'KD Singh Babu Stadium',
        hindiName: 'के.डी. सिंह बाबू स्टेडियम',
        city: city,
        latitude: 26.8585,
        longitude: 80.9425,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_vishwavidyalaya',
        name: 'Vishwavidyalaya (Lucknow University)',
        hindiName: 'विश्वविद्यालय',
        city: city,
        latitude: 26.8660,
        longitude: 80.9412,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_it_college',
        name: 'IT College',
        hindiName: 'आईटी कॉलेज',
        city: city,
        latitude: 26.8720,
        longitude: 80.9430,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_badshahnagar',
        name: 'Badshahnagar',
        hindiName: 'बादशाहनगर',
        city: city,
        latitude: 26.8745,
        longitude: 80.9575,
        lineIds: ['lucknow_red'],
        isInterchange: true,
      ),
      const Station(
        id: 'lko_lekhraj_market',
        name: 'Lekhraj Market',
        hindiName: 'लेखराज मार्केट',
        city: city,
        latitude: 26.8752,
        longitude: 80.9705,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_bhootnath_market',
        name: 'Bhootnath Market',
        hindiName: 'भूतनाथ मार्केट',
        city: city,
        latitude: 26.8755,
        longitude: 80.9810,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_indira_nagar',
        name: 'Indira Nagar',
        hindiName: 'इंदिरा नगर',
        city: city,
        latitude: 26.8760,
        longitude: 80.9912,
        lineIds: ['lucknow_red'],
      ),
      const Station(
        id: 'lko_munshi_pulia',
        name: 'Munshi Pulia',
        hindiName: 'मुंशी पुलिया',
        city: city,
        latitude: 26.8830,
        longitude: 81.0025,
        lineIds: ['lucknow_red'],
      ),
    ];

    for (final s in stations) {
      graph.addStation(s);
    }

    for (int i = 0; i < stations.length - 1; i++) {
      graph.addBidirectionalRailEdge(
        from: stations[i],
        to: stations[i + 1],
        lineId: redLine.id,
        travelTimeSeconds: 120, // 2 mins per station
      );
    }
  }
}
