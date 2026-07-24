Feature: Editor erase tool
  The erase brush paints into a photo layer's mask by dragging on the canvas.

  Background:
    Given the app is freshly launched
    And I create a new blank project
    And a photo layer is added

  Scenario: Dragging erases part of the photo
    When I tap the {'Erase'} tool
    And I drag across the photo on the canvas
    Then the selected photo has a mask
    And no unhandled error occurred

  Scenario: Selecting the erase tool alone leaves the photo untouched
    When I tap the {'Erase'} tool
    Then the selected photo has no mask
    And no unhandled error occurred
