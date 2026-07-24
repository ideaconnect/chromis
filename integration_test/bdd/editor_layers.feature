Feature: Editor layer management
  Layers can be added, listed, duplicated, hidden and deleted, and edits are
  reversible with undo/redo.

  Background:
    Given the app is freshly launched
    And I create a new blank project

  Scenario: Add a text layer and see it listed
    When I add a text layer
    And I tap the {'Layers'} tool
    Then the project has {1} layers
    And I see {'Text layer'}
    And no unhandled error occurred

  Scenario: Duplicate then delete a layer
    When I add a text layer
    And I tap the {'Layers'} tool
    And I duplicate the selected layer
    Then the project has {2} layers
    When I delete the selected layer
    Then the project has {1} layers

  Scenario: Toggle layer visibility
    When I add a text layer
    And I tap the {'Layers'} tool
    And I hide the selected layer
    Then the selected layer is hidden

  Scenario: Undo and redo a layer add
    When I add a text layer
    Then the project has {1} layers
    When I undo the last action
    Then the project has {0} layers
    When I redo the last action
    Then the project has {1} layers
