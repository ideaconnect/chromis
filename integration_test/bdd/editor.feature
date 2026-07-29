Feature: Core editing on a blank canvas
  Creating a project opens a live editor canvas, and layers can be added without
  importing a photo.

  Scenario: Create a new project and open the editor
    Given the app is freshly launched
    When I create a new blank project
    Then the editor is shown
    And no unhandled error occurred

  Scenario: Add a comic bubble layer
    Given the app is freshly launched
    When I create a new blank project
    And I tap the {'Bubble'} tool
    And I pick the {'Speech'} bubble format
    Then a comic bubble layer is added
    And no unhandled error occurred
