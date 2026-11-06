# BagSmith plugins and API

Documentation for addon authors: how to add your own marks to BagSmith's item icons, how to write a BagSmith
plugin, and the API both use. These docs and the example plugin are MIT licensed (see LICENSE here), so copy
freely.

**Current API: BagSmith.API 1.1** (BagSmith 1.5.0). It only ever grows; see [API changes](API-CHANGES.md).

## Start here

- **Adding marks to BagSmith's item icons** (Pawn-style arrows, badges, rings): read the icon corner section of
  [API.md](API.md#icon-corner-widgets-11), then copy a shape from [EXAMPLES.md](EXAMPLES.md). If your
  addon already supports another bag addon's corner widgets, it's usually a few lines.
- **Writing a BagSmith plugin:** [QUICKSTART.md](QUICKSTART.md) builds a minimal working plugin, and
  [`BagSmith_ExamplePlugin`](../BagSmith_ExamplePlugin) is a complete starter addon.

## Reference

- [API.md](API.md): the full contract
- [EXAMPLES.md](EXAMPLES.md): icon corner examples
- [COMPATIBILITY.md](COMPATIBILITY.md): versions, and what a plugin can rely on
- [AUTHOR-GUIDELINES.md](AUTHOR-GUIDELINES.md): the rules of the road
- [API-CHANGES.md](API-CHANGES.md): what changed in each API version
- [USING-PLUGINS.md](USING-PLUGINS.md): how players install and manage plugins

## Testing your plugin

The repository's `tests` folder has a mock WoW client and BagSmith's own test sets, and `tools/run_tests.py`
runs them (see the main README). `tests/plugins_example_tests.lua` shows how the example plugin is tested.

## Questions and requests

Open an issue here. In game, `/bs corners` lists every icon mark BagSmith knows, and `/bs debug` prints errors
from your callbacks as they happen.
