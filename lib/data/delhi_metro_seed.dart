import '../models/station.dart';
import '../models/transit_line.dart';
import '../graph/transit_graph.dart';

class DelhiMetroSeed {
  static const String city = 'Delhi';

  static const TransitLine yellowLine = TransitLine(
    id: 'delhi_yellow',
    name: 'Yellow Line',
    city: city,
    colorHex: '#FACC15', // Vibrant Yellow
    code: 'YL',
  );

  static const TransitLine blueLine = TransitLine(
    id: 'delhi_blue',
    name: 'Blue Line',
    city: city,
    colorHex: '#2563EB', // Blue
    code: 'BL',
  );

  static const TransitLine magentaLine = TransitLine(
    id: 'delhi_magenta',
    name: 'Magenta Line',
    city: city,
    colorHex: '#D946EF', // Magenta
    code: 'ML',
  );

  static const TransitLine redLine = TransitLine(
    id: 'delhi_red',
    name: 'Red Line',
    city: city,
    colorHex: '#DC2626', // Red
    code: 'RL',
  );

  static const TransitLine violetLine = TransitLine(
    id: 'delhi_violet',
    name: 'Violet Line',
    city: city,
    colorHex: '#7C3AED', // Violet
    code: 'VL',
  );

  static const TransitLine airportLine = TransitLine(
    id: 'delhi_airport',
    name: 'Airport Express',
    city: city,
    colorHex: '#EA580C', // Orange
    code: 'AL',
  );

  static void populate(TransitGraph graph) {
    // 1. Add Lines
    graph.addLine(yellowLine);
    graph.addLine(blueLine);
    graph.addLine(magentaLine);
    graph.addLine(redLine);
    graph.addLine(violetLine);
    graph.addLine(airportLine);

    // 2. Yellow Line Stations
    const samaypurBadli = Station(
      id: 'delhi_samaypur_badli',
      name: 'Samaypur Badli',
      hindiName: 'समयपुर बादली',
      city: city,
      latitude: 28.7460,
      longitude: 77.1352,
      lineIds: ['delhi_yellow'],
    );

    const azadpur = Station(
      id: 'delhi_azadpur',
      name: 'Azadpur',
      hindiName: 'आज़ादपुर',
      city: city,
      latitude: 28.7067,
      longitude: 77.1812,
      lineIds: ['delhi_yellow'],
      isInterchange: true,
    );

    const kashmereGate = Station(
      id: 'delhi_kashmere_gate',
      name: 'Kashmere Gate',
      hindiName: 'कश्मीरी गेट',
      city: city,
      latitude: 28.6675,
      longitude: 77.2285,
      lineIds: ['delhi_yellow', 'delhi_red', 'delhi_violet'],
      isInterchange: true,
      undergroundDepthLevel: 2,
      isDeadzone: true,
    );

    const chandniChowk = Station(
      id: 'delhi_chandni_chowk',
      name: 'Chandni Chowk',
      hindiName: 'चाँदनी चौक',
      city: city,
      latitude: 28.6578,
      longitude: 77.2301,
      lineIds: ['delhi_yellow'],
      undergroundDepthLevel: 2,
      isDeadzone: true,
    );

    const chawriBazar = Station(
      id: 'delhi_chawri_bazar',
      name: 'Chawri Bazar',
      hindiName: 'चावड़ी बाज़ार',
      city: city,
      latitude: 28.6496,
      longitude: 77.2263,
      lineIds: ['delhi_yellow'],
      undergroundDepthLevel: 3,
      isDeadzone: true, // Known deep underground deadzone
    );

    const newDelhi = Station(
      id: 'delhi_new_delhi',
      name: 'New Delhi',
      hindiName: 'नई दिल्ली',
      city: city,
      latitude: 28.6431,
      longitude: 77.2223,
      lineIds: ['delhi_yellow', 'delhi_airport'],
      isInterchange: true,
      undergroundDepthLevel: 2,
      isDeadzone: true,
    );

    const rajivChowk = Station(
      id: 'delhi_rajiv_chowk',
      name: 'Rajiv Chowk (Connaught Place)',
      hindiName: 'राजीव चौक',
      city: city,
      latitude: 28.6328,
      longitude: 77.2197,
      lineIds: ['delhi_yellow', 'delhi_blue'],
      isInterchange: true,
      undergroundDepthLevel: 2,
      isDeadzone: true, // Major transit interchange & deep deadzone
    );

    const patelChowk = Station(
      id: 'delhi_patel_chowk',
      name: 'Patel Chowk',
      hindiName: 'पटेल चौक',
      city: city,
      latitude: 28.6232,
      longitude: 77.2133,
      lineIds: ['delhi_yellow'],
      undergroundDepthLevel: 1,
    );

    const centralSecretariat = Station(
      id: 'delhi_central_secretariat',
      name: 'Central Secretariat',
      hindiName: 'केंद्रीय सचिवालय',
      city: city,
      latitude: 28.6146,
      longitude: 77.2119,
      lineIds: ['delhi_yellow', 'delhi_violet'],
      isInterchange: true,
      undergroundDepthLevel: 1,
    );

    const aiims = Station(
      id: 'delhi_aiims',
      name: 'AIIMS',
      hindiName: 'एम्स',
      city: city,
      latitude: 28.5684,
      longitude: 77.2076,
      lineIds: ['delhi_yellow'],
      undergroundDepthLevel: 1,
    );

    const hauzKhas = Station(
      id: 'delhi_hauz_khas',
      name: 'Hauz Khas',
      hindiName: 'हौज़ ख़ास',
      city: city,
      latitude: 28.5431,
      longitude: 77.2065,
      lineIds: ['delhi_yellow', 'delhi_magenta'],
      isInterchange: true,
      undergroundDepthLevel: 4, // Deepest station platform in India (29 meters)
      isDeadzone: true,
    );

    const malviyaNagar = Station(
      id: 'delhi_malviya_nagar',
      name: 'Malviya Nagar',
      hindiName: 'मालवीय नगर',
      city: city,
      latitude: 28.5282,
      longitude: 77.2064,
      lineIds: ['delhi_yellow'],
      undergroundDepthLevel: 1,
    );

    const saket = Station(
      id: 'delhi_saket',
      name: 'Saket',
      hindiName: 'साकेत',
      city: city,
      latitude: 28.5202,
      longitude: 77.2016,
      lineIds: ['delhi_yellow'],
    );

    const millenniumCity = Station(
      id: 'delhi_millennium_city',
      name: 'Millennium City Centre Gurugram',
      hindiName: 'मिलेनियम सिटी सेंटर',
      city: city,
      latitude: 28.4593,
      longitude: 77.0725,
      lineIds: ['delhi_yellow'],
    );

    final yellowStations = [
      samaypurBadli,
      azadpur,
      kashmereGate,
      chandniChowk,
      chawriBazar,
      newDelhi,
      rajivChowk,
      patelChowk,
      centralSecretariat,
      aiims,
      hauzKhas,
      malviyaNagar,
      saket,
      millenniumCity,
    ];

    for (final s in yellowStations) {
      graph.addStation(s);
    }

    for (int i = 0; i < yellowStations.length - 1; i++) {
      graph.addBidirectionalRailEdge(
        from: yellowStations[i],
        to: yellowStations[i + 1],
        lineId: yellowLine.id,
        travelTimeSeconds: 150, // ~2.5 mins per stop
      );
    }

    // 3. Blue Line Stations
    const dwarkaSec21 = Station(
      id: 'delhi_dwarka_sec_21',
      name: 'Dwarka Sector 21',
      hindiName: 'द्वारका सेक्टर 21',
      city: city,
      latitude: 28.5522,
      longitude: 77.0583,
      lineIds: ['delhi_blue', 'delhi_airport'],
      isInterchange: true,
    );

    const janakpuriWest = Station(
      id: 'delhi_janakpuri_west',
      name: 'Janakpuri West',
      hindiName: 'जनकपुरी पश्चिम',
      city: city,
      latitude: 28.6294,
      longitude: 77.0782,
      lineIds: ['delhi_blue', 'delhi_magenta'],
      isInterchange: true,
    );

    const karolBagh = Station(
      id: 'delhi_karol_bagh',
      name: 'Karol Bagh',
      hindiName: 'करोल बाग़',
      city: city,
      latitude: 28.6441,
      longitude: 77.1901,
      lineIds: ['delhi_blue'],
    );

    const rkAshram = Station(
      id: 'delhi_rk_ashram',
      name: 'RK Ashram Marg',
      hindiName: 'आर.के. आश्रम मार्ग',
      city: city,
      latitude: 28.6391,
      longitude: 77.2091,
      lineIds: ['delhi_blue'],
    );

    const barakhamba = Station(
      id: 'delhi_barakhamba',
      name: 'Barakhamba Road',
      hindiName: 'बाराखंभा रोड',
      city: city,
      latitude: 28.6310,
      longitude: 77.2272,
      lineIds: ['delhi_blue'],
      undergroundDepthLevel: 1,
    );

    const mandiHouse = Station(
      id: 'delhi_mandi_house',
      name: 'Mandi House',
      hindiName: 'मंडी हाउस',
      city: city,
      latitude: 28.6258,
      longitude: 77.2343,
      lineIds: ['delhi_blue', 'delhi_violet'],
      isInterchange: true,
      undergroundDepthLevel: 2,
      isDeadzone: true,
    );

    const botanicalGarden = Station(
      id: 'delhi_botanical_garden',
      name: 'Botanical Garden',
      hindiName: 'बॉटनिकल गार्डन',
      city: city,
      latitude: 28.5645,
      longitude: 77.3342,
      lineIds: ['delhi_blue', 'delhi_magenta'],
      isInterchange: true,
    );

    const noidaElecCity = Station(
      id: 'delhi_noida_elec_city',
      name: 'Noida Electronic City',
      hindiName: 'नोएडा इलेक्ट्रॉनिक सिटी',
      city: city,
      latitude: 28.6277,
      longitude: 77.3732,
      lineIds: ['delhi_blue'],
    );

    final blueStations = [
      dwarkaSec21,
      janakpuriWest,
      karolBagh,
      rkAshram,
      rajivChowk,
      barakhamba,
      mandiHouse,
      botanicalGarden,
      noidaElecCity,
    ];

    for (final s in blueStations) {
      graph.addStation(s);
    }

    for (int i = 0; i < blueStations.length - 1; i++) {
      graph.addBidirectionalRailEdge(
        from: blueStations[i],
        to: blueStations[i + 1],
        lineId: blueLine.id,
        travelTimeSeconds: 160,
      );
    }

    // 4. Magenta Line Stations (Connecting Janakpuri West <-> Hauz Khas <-> Botanical Garden)
    const igiAirportT1 = Station(
      id: 'delhi_igi_t1',
      name: 'Terminal 1 IGI Airport',
      hindiName: 'आईजीआई एयरपोर्ट टी-1',
      city: city,
      latitude: 28.5583,
      longitude: 77.0988,
      lineIds: ['delhi_magenta'],
      undergroundDepthLevel: 2,
      isDeadzone: true,
    );

    const kalkajiMandir = Station(
      id: 'delhi_kalkaji_mandir',
      name: 'Kalkaji Mandir',
      hindiName: 'कालकाजी मंदिर',
      city: city,
      latitude: 28.5492,
      longitude: 77.2588,
      lineIds: ['delhi_magenta', 'delhi_violet'],
      isInterchange: true,
    );

    final magentaStations = [
      janakpuriWest,
      igiAirportT1,
      hauzKhas,
      kalkajiMandir,
      botanicalGarden,
    ];

    for (final s in magentaStations) {
      graph.addStation(s);
    }

    for (int i = 0; i < magentaStations.length - 1; i++) {
      graph.addBidirectionalRailEdge(
        from: magentaStations[i],
        to: magentaStations[i + 1],
        lineId: magentaLine.id,
        travelTimeSeconds: 210, // Express stretches
      );
    }

    // 5. Red Line (Rithala <-> Kashmere Gate <-> Shaheed Sthal)
    const rithala = Station(
      id: 'delhi_rithala',
      name: 'Rithala',
      hindiName: 'रिठाला',
      city: city,
      latitude: 28.7208,
      longitude: 77.1072,
      lineIds: ['delhi_red'],
    );

    const shaheedSthal = Station(
      id: 'delhi_shaheed_sthal',
      name: 'Shaheed Sthal (New Bus Adda)',
      hindiName: 'शहीद स्थल',
      city: city,
      latitude: 28.6710,
      longitude: 77.4243,
      lineIds: ['delhi_red'],
    );

    graph.addStation(rithala);
    graph.addStation(shaheedSthal);
    graph.addBidirectionalRailEdge(
      from: rithala,
      to: kashmereGate,
      lineId: redLine.id,
      travelTimeSeconds: 520,
    );
    graph.addBidirectionalRailEdge(
      from: kashmereGate,
      to: shaheedSthal,
      lineId: redLine.id,
      travelTimeSeconds: 600,
    );

    // 6. Subterranean Interchange Walking Vectors
    graph.addInterchangeTransfer(
      stationAId: rajivChowk.id,
      stationBId: rajivChowk.id, // Internal transfer
      transferWalkSeconds: 180,
      walkingVector:
          'Take central escalators down to Level -2: Platform 3 (Noida/Vaishali) or Platform 4 (Dwarka Sec 21)',
    );

    graph.addInterchangeTransfer(
      stationAId: hauzKhas.id,
      stationBId: hauzKhas.id,
      transferWalkSeconds: 240,
      walkingVector:
          'Follow Magenta Line signage down 29m via high-speed escalators to Platform 1 & 2',
    );

    graph.addInterchangeTransfer(
      stationAId: kashmereGate.id,
      stationBId: kashmereGate.id,
      transferWalkSeconds: 210,
      walkingVector:
          'Take concourse walkway connecting Level 1 (Red Line) to Sub-surface (Yellow / Violet Lines)',
    );

    graph.addInterchangeTransfer(
      stationAId: mandiHouse.id,
      stationBId: mandiHouse.id,
      transferWalkSeconds: 120,
      walkingVector: 'Follow interchange ramp between Blue Line and Violet Line platforms',
    );

    graph.addInterchangeTransfer(
      stationAId: centralSecretariat.id,
      stationBId: centralSecretariat.id,
      transferWalkSeconds: 60,
      walkingVector: 'Cross-platform transfer across the island platform',
    );
  }
}
