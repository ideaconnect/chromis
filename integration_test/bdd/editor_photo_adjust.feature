Feature: Editor photo adjustments
  Brightness, contrast, saturation, opacity and the cutout outline change a
  photo layer, and Reset restores the identity look.

  Background:
    Given the app is freshly launched
    And I create a new blank project
    And a photo layer is added

  Scenario: Brightness changes the photo
    When I tap the {'Adjust'} tool
    And I move the {'Brightness'} slider
    Then the selected photo has been adjusted

  Scenario: Several adjustments then reset
    When I tap the {'Adjust'} tool
    And I move the {'Contrast'} slider
    And I move the {'Saturation'} slider
    And I move the {'Opacity'} slider
    And I move the {'Cutout outline'} slider
    Then the selected photo has been adjusted
    When I tap {'Reset'}
    Then the selected photo has default adjustments
