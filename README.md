# Artillery Rampage

## Info

Project uses Godot 4.4.1 with GDScript.

## Inspiration

- [Tank Wars Design Breakdown](https://www.youtube.com/watch?v=l0DzDR9B6To)
- [Tank Wars DOS Longplay](https://www.youtube.com/watch?v=Nl8YiKuGFGc)

## Contribution Guidelines

In Godot `snake_case` rules the day.  Folders and files should start with lower case letter and use `_` between words.

See [Godot Naming Style Guide](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html#importing)

The folder structure is organized by "feature" rather than technical concern.  Instead of having a root `scenes` and `scripts` folder, we will place the scripts in the same folder as the scene file that loads that script. Any models or image for those models specific to that scene, e.g. Tank, would go in the same folder or a sub folder under that for organization purposes.  This makes it easier to find things and the project feels more cohesive overall.  Some cross-cutting or technical-only features like events may go in their own folder structure.

When contributing assets, any assets that should be bundled in the game like `.png` files for sprites or `.wav` files for audio should go in a "feature" folder or create one if it does not yet exist.  We can always move stuff around if needed.  Any "source" assets like gimp or photoshop files or Audacity project files if you want to include them should go under the `assets` folder as this has a `.gdignore` file so that Godot doesn't try to parse them as they are not intended to go into the final game.
