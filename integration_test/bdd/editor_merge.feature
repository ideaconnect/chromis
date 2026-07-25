Feature: Merging and flattening layers
  Stacked layers can be folded into one photo - either a pair with Merge down
  or the whole stack with Flatten - and it is a single undoable step.

  Background:
    Given the app is freshly launched
    And I create a new blank project

  Scenario: Nothing to merge with a single layer
    When I add a text layer
    And I tap the {'Layers'} tool
    Then the project has {1} layers
    And I do not see {'Merge down'}
    And I do not see {'Flatten'}

  Scenario: Merge the selected layer into the one below
    When a photo layer is added
    And I add a text layer
    And I tap the {'Layers'} tool
    Then the project has {2} layers
    When I tap {'Merge down'}
    Then the project has {1} layers
    And the selected layer is a photo
    And no unhandled error occurred

  Scenario: Flatten the whole stack
    When a photo layer is added
    And a photo layer is added
    And I add a text layer
    And I tap the {'Layers'} tool
    Then the project has {3} layers
    When I tap {'Flatten'}
    Then the project has {1} layers
    And the selected layer is a photo

  Scenario: A merge is one undo step
    When a photo layer is added
    And I add a text layer
    And I tap the {'Layers'} tool
    And I tap {'Flatten'}
    Then the project has {1} layers
    When I undo the last action
    Then the project has {2} layers
    And no unhandled error occurred
