/// s17's sun, kept to show what the span rule does with the picture the kit
/// redraws: a sun, a cloud and a sea bar, its pieces stretched across the
/// board.
const todaySun = '''
{
  "id": "sun",
  "name": "Sun",
  "level": "easy",
  "pieces": [
    {"id": "rays", "shape": {"polygon": [[0, -15], [3.82, -5.26], [14.27, -4.64], [6.18, 2.01], [8.82, 12.14], [0, 6.5], [-8.82, 12.14], [-6.18, 2.01], [-14.27, -4.64], [-3.82, -5.26]]}, "color": "#E9762B", "at": [26, 28], "rotated": true, "big": true},
    {"id": "sun", "shape": {"circle": 7}, "color": "#F2C200", "at": [26, 28]},
    {"id": "cloud", "shape": {"polygon": [[-9, 3], [-7, -2], [-3, -3], [-1, -5], [5, -5], [8, -1], [9, 2], [9, 5]]}, "color": "#85C1E9", "at": [58, 20], "rotated": true},
    {"id": "sea", "shape": {"rect": [44, 5]}, "color": "#3498DB", "at": [40, 62]}
  ]
}
''';

/// s17's fish: a body, a tail, a fin, an eye and a bubble far off to the left.
const todayFish = '''
{
  "id": "fish",
  "name": "Fish",
  "level": "easy",
  "pieces": [
    {"id": "body", "shape": {"circle": 13}, "color": "#E9762B", "at": [34, 40], "big": true},
    {"id": "tail", "shape": {"polygon": [[-4.6667, -8], [-4.6667, 8], [9.3333, 0]]}, "color": "#C0392B", "at": [51.6667, 40], "rotated": true},
    {"id": "fin", "shape": {"polygon": [[-6, 4], [6, 4], [0, -8]]}, "color": "#2E86C1", "at": [34, 22], "rotated": true},
    {"id": "eye", "shape": {"circle": 7}, "color": "#F2C200", "at": [28, 35]},
    {"id": "bubble", "shape": {"polygon": [[0, -7], [7, 0], [0, 7], [-7, 0]]}, "color": "#5DADE2", "at": [18, 18]}
  ]
}
''';

/// s17's butterfly: four wings round a body, the picture smaller than the
/// board's 60%.
const todayButterfly = '''
{
  "id": "butterfly",
  "name": "Butterfly",
  "level": "medium",
  "pieces": [
    {"id": "body", "shape": {"rect": [8, 24]}, "color": "#6D4C41", "at": [40, 41], "big": true},
    {"id": "upper left", "shape": {"polygon": [[-10, -8], [6, -10], [12, 2], [-4, 10]]}, "color": "#A66CFF", "at": [27, 32], "rotated": true},
    {"id": "upper right", "shape": {"polygon": [[-12, -2], [-6, -10], [10, -8], [4, 10]]}, "color": "#E9762B", "at": [53, 32], "rotated": true},
    {"id": "lower left", "shape": {"polygon": [[-8, -6], [4, -8], [6, 6], [-6, 8]]}, "color": "#27AE60", "at": [28, 50]},
    {"id": "lower right", "shape": {"polygon": [[-6, -6], [8, -4], [4, 8], [-8, 4]]}, "color": "#2E86C1", "at": [52, 50]},
    {"id": "spot left", "shape": {"circle": 6}, "color": "#F2C200", "at": [27, 32]},
    {"id": "spot right", "shape": {"circle": 6}, "color": "#F2C200", "at": [53, 32]}
  ]
}
''';
