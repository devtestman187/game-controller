/// The bundled maps' names by id (M16 n9d3): the HUD names the map in the round, and a snapshot carries
/// only the map's id, so the name is looked up here. A map that is not listed shows no name. A test
/// reads each name from the map's own file, so this list cannot drift from `maps/`.
const arenaMapNames = <String, String>{
  'playroom': 'Playroom',
  'pinball': 'Pinball',
  'block-castle': 'Block Castle',
  'toy-factory': 'Toy Factory',
  'spinning-tops': 'Spinning Tops',
};
