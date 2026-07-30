Feature: Editor photo crop
  A photo layer can be cropped and the crop can be reset back to the full
  frame. The first scenario drives the real Crop button and the crop overlay on
  the device; the other two exercise the state path directly, which is cheaper
  but cannot see a decode that fails only outside a host test.

  Background:
    Given the app is freshly launched
    And I create a new blank project
    And a photo layer is added

  Scenario: Crop a photo with the Crop button
    When I tap the {'Adjust'} tool
    And I open the photo crop editor
    And I drag the crop box corner inwards
    And I confirm the crop
    Then the selected photo is cropped
    And no unhandled error occurred

  Scenario: Crop a photo
    When the photo is cropped to the right half
    Then the selected photo is cropped
    And no unhandled error occurred

  Scenario: Reset a crop
    When the photo is cropped to the right half
    And the photo crop is reset
    Then the selected photo is not cropped
