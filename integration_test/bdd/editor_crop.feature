Feature: Editor photo crop
  A photo layer can be cropped and the crop can be reset back to the full
  frame.

  Background:
    Given the app is freshly launched
    And I create a new blank project
    And a photo layer is added

  Scenario: Crop a photo
    When the photo is cropped to the right half
    Then the selected photo is cropped
    And no unhandled error occurred

  Scenario: Reset a crop
    When the photo is cropped to the right half
    And the photo crop is reset
    Then the selected photo is not cropped
