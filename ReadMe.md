# Helios Highlander

A highlander for XCom: Chimera Squad, originally made for an overhaul mod, now a highlander in which anyone can contribute to. This builds upon [RealityMachina's Highlander](https://github.com/RealityMachina/ChimeraSquadHighlander).

This highlander is considered experimental and therefore there is no release on the Steam Workshop.

## Features
[Highlander Features](https://github.com/E3245/HeliosHighlander/wiki/Features)

## Development
[See X2WOTCCommunityHighlander#Development](https://github.com/X2CommunityCore/X2WOTCCommunityHighlander/#development).

### Discussion
Discussion happens in (as of 4/30/21) #chimera-mod-dev of the [XCom 2 Modding discord server](https://discordapp.com/invite/vvsXvs3).

## Building
[See X2WOTCCommunityHighlander#Building](https://github.com/X2CommunityCore/X2WOTCCommunityHighlander#cooking-a-final-release-manual-method).

The following files are needed from `%STEAMLIBRARY%\steamapps\common\XCOM-Chimera-Squad\XComGame\CookedPCConsole` and pasted into `%STEAMLIBRARY%\steamapps\common\XCOM-Chimera-Squad-SDK\XComGame\Published\CookedPCConsole`: 
```
GuidCache.upk
GlobalPersistentCookerData.upk
PersistentCookerShaderData.bin
*.tfc
```

An updated version of the VSCode Extension for Chimera Squad can be found [here](https://github.com/X2CommunityCore/VSCode-Extension) that handles the cooking process, along with some QoL features and fixes.

Otherwise, you'll need to run these two commands to cook the highlander:
```
"%STEAMLIBRARY%\steamapps\common\XCOM-Chimera-Squad-SDK\Binaries\Win64\XComGame.exe" make -final_release -full
"%STEAMLIBRARY%\steamapps\common\XCOM-Chimera-Squad-SDK\Binaries\Win64\XComGame.exe" CookPackages -platform=pcconsole -final_release -quickanddirty -modcook -sha -multilanguagecook=INT+FRA+ITA+DEU+RUS+POL+KOR+ESN -singlethread
```
