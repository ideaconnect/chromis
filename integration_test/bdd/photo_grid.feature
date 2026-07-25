Feature: Photo grid (collage)
  A collage opens on its Grid tool, where the photo count, layout and border
  are always reachable, and it exports like any other project.

  # The create flow itself ends in the system photo picker, a separate process
  # that rejects synthetic input on this device, so these scenarios seed the
  # collage through the controller and drive the editor from there. Creating one
  # by hand stays a manual device check (docs/e2e-testing.md).

  Scenario: The Grid tool is the collage's home
    Given the app is freshly launched
    And I create a new blank project
    And a photo grid project is open with {3} photos
    Then I see {'Photo grid'}
    And I see {'PHOTOS'}
    And I see {'LAYOUT'}
    And no unhandled error occurred

  Scenario: Change the layout and the photo count
    Given the app is freshly launched
    And I create a new blank project
    And a photo grid project is open with {3} photos
    When I tap {'Rows'}
    And I tap {'4'}
    Then I see {'Photo grid'}
    And no unhandled error occurred

  Scenario: Restyle the border
    Given the app is freshly launched
    And I create a new blank project
    And a photo grid project is open with {2} photos
    When I move the {'Border'} slider
    And I move the {'Corners'} slider
    Then no unhandled error occurred

  Scenario: Export a collage
    Given the app is freshly launched
    And I create a new blank project
    And a photo grid project is open with {2} photos
    When I tap {'Export'}
    Then I see {'Export & share'}
    And no unhandled error occurred
