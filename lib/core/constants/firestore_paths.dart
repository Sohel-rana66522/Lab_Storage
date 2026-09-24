/// Firestore collection names in one place.
class Col {
  Col._();
  static const users = 'users';
  static const categories = 'categories';
  static const chemicals = 'chemicals';
  static const transactions = 'transactions';
}

/// Standard folders offered when a lab starts with an empty archive.
const defaultFolderNames = <String>[
  'Acids',
  'Bases',
  'Salts',
  'Solvents',
  'Dyes & Pigments',
  'Indicators',
  'Other Chemicals',
];

/// Filter tags shown as chips on the home screen (from the Stitch design).
const chemicalTags = <String>['Inorganic', 'Organic', 'Volatile', 'Flammable'];

const hazardClasses = <String>[
  'Corrosive',
  'Flammable',
  'Toxic',
  'Oxidizer',
  'Irritant',
  'Compressed gas',
];
