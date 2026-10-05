# SMH Offsetter <!-- omit from toc -->

Move a recorded physics-bone animation relative to an offsetter entity

## Table of Contents <!-- omit from toc -->

- [Description](#description)
  - [Features](#features)
- [Usage](#usage)
- [Disclaimer](#disclaimer)

## Description

SMH Offsetter creates a hologram for a source ragdoll and applies the source's physics bone motion relative to an offsetter entity. This makes it possible to animate a walk or run cycle in place, then move and rotate the offsetter to place that animation elsewhere.

### Features

- **World-space motion remapping**: Each source physics bone's movement is applied to the corresponding bone on its hologram.
- **Multiple sources**: Attach more than one source ragdoll to the same offsetter. Each source has its own hologram.
- **Adjustable origin offset**: Change the offsetter's X, Y, and Z values to reposition the holograms relative to its origin.
- **Origin recapture**: View attached source and hologram pairs in the stool panel, select a pair, and recapture its origin.
- **GMod Save support**: Save the offsetter with its linked sources and holograms to preserve their relationships and origins.

## Usage

1. Go to Entities tab -> **Stop Motion Helper** category to spawn an Offsetter entity.
2. Select the **Offsetter** tool under **Stop Motion Helper**.
3. Left-click a source ragdoll, then left-click the offsetter. A hologram (which is a duplicate of your animation) is created for the source.
4. Repeat the selection steps to attach additional source ragdolls to the same offsetter.
5. Move or rotate the offsetter to place the holograms. Right-click the Offsetter -> Edit Properties... to edit the relative position of all holograms.
6. Use the tool's control panel to view attached pairs. Select a row and choose **Recapture selected zero point** to set a new origin for that pair, relative to the Offsetter entity.
7. Reload-click a linked source ragdoll to remove its hologram and stop tracking it.

All offsetters, linked source ragdolls, and their holograms, can be saved in a GMod save.

> [!NOTE]
> Loading offsetters will automatically set origins for any holograms in the scene. Make sure that your holograms are in the correct relative position to your offsetters. If not, you will need to perform an origin recapture again

## Disclaimer

**This tool has been tested in singleplayer.** Although it may function in multiplayer, please expect bugs and report any that you observe in the issue tracker.
