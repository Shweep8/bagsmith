Libraries embedded in BagSmith, unmodified:

- LibStub (minor 2), from the Ace3 repository (github.com/WoWUIDev/Ace3). Public domain.
- CallbackHandler-1.0 (minor 8), from the Ace3 repository. Ace3 license (LICENSE.txt in its folder).
- LibDataBroker-1.1 (minor 4), from github.com/tekkub/libdatabroker-1-1.
- LibDBIcon-1.0 (minor 56), the library's release as embedded in Questie (github.com/Questie/Questie).
  Official project: curseforge.com/wow/addons/libdbicon-1-0.

They give BagSmith a standard minimap button, so UI addons and minimap button
managers (MayronUI, ElvUI, SexyMap and others) can fade, hide or collect it like
other addons' buttons. If another addon loads newer copies, LibStub uses those.
