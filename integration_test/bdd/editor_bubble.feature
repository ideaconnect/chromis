Feature: Editor comic bubble tool
  A comic bubble is created in a format the user picks, and can then change
  format, hold text, and take fill and outline colours.

  Background:
    Given the app is freshly launched
    And I create a new blank project

  Scenario: Add a comic bubble layer
    When I tap the {'Bubble'} tool
    And I pick the {'Speech'} bubble format
    Then a comic bubble layer is added
    And no unhandled error occurred

  Scenario Outline: Every format can be picked when adding a bubble
    When I tap the {'Bubble'} tool
    And I pick the {'<format>'} bubble format
    Then a comic bubble layer is added
    And the selected bubble shape is {'<format>'}
    And no unhandled error occurred

    Examples:
      | format  |
      | Speech  |
      | Thought |
      | Shout   |
      | Caption |
      | Whisper |

  Scenario: Dismissing the format picker adds nothing
    When I tap the {'Bubble'} tool
    And I dismiss the bubble format picker
    Then no comic bubble layer was added
    And no unhandled error occurred

  Scenario: Change the format and the text
    When I tap the {'Bubble'} tool
    And I pick the {'Speech'} bubble format
    And I change the bubble format to {'Thought'}
    And I enter {'Boom'} as the bubble text
    Then the selected bubble shape is {'Thought'}
    And the selected bubble text is {'Boom'}

  Scenario: Set fill and outline colours
    When I tap the {'Bubble'} tool
    And I pick the {'Caption'} bubble format
    And I pick a different {'Fill'} color
    And I pick a different {'Outline'} color
    Then the selected bubble {'Fill'} color changed
    And the selected bubble {'Outline'} color changed
