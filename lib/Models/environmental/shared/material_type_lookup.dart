import 'package:impact_trail/models/environmental/enums/material_category.dart';

class MaterialTypeLookup {
  MaterialTypeLookup._();

  static const Map<MaterialCategory, List<String>> types = {
    MaterialCategory.plastics: [
      'PET Clean',
      'PET Contaminated',
      'HDPE Natural',
      'HDPE Mixed',
      'LDPE Film',
      'Carrier Bags',
      'Soft Film',
      'PP Mixed',
      'PVC',
      'Polystyrene',
    ],
    MaterialCategory.metals: [
      'Copper Wire',
      'Copper Scrap',
      'Aluminium Cans',
      'Aluminium Sheet',
      'Steel',
      'Iron',
      'Tin',
    ],
    MaterialCategory.glass: [
      'Clear Glass',
      'Green Glass',
      'Brown Glass',
      'Mixed Glass',
    ],
    MaterialCategory.paperCardboard: [
      'Cardboard OCC',
      'Newspaper',
      'Office Paper',
      'Mixed Paper',
    ],
    MaterialCategory.rubberComposites: [
      'Tyres',
      'Rubber Sheet',
      'Mixed Rubber',
    ],
    MaterialCategory.reclaimedWood: [
      'Pallets',
      'Hardwood',
      'Softwood',
      'MDF',
    ],
    MaterialCategory.textiles: [
      'Cotton',
      'Denim',
      'Mixed Fabric',
      'Leather',
    ],
    MaterialCategory.electronics: [
      'Cables',
      'PCBs',
      'Mobile Phones',
      'Computer Parts',
    ],
  };

  static List<String> forCategory(MaterialCategory category) =>
      types[category] ?? const [];
}
