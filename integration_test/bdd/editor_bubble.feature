Feature: Editor comic bubble tool
  A comic bubble can change shape, hold text, and take fill and outline
  colours.

  Background:
    Given the app is freshly launched
    And I create a new blank project

  Scenario: Add a comic bubble layer
    When I tap the {'Bubble'} tool
    Then a comic bubble layer is added
    And no unhandled error occurred

  Scenario: Change the shape and the text
    When I tap the {'Bubble'} tool
    And I tap {'Thought'}
    And I enter {'Boom'} as the bubble text
    Then the selected bubble shape is {'Thought'}
    And the selected bubble text is {'Boom'}

  Scenario: Set fill and outline colours
    When I tap the {'Bubble'} tool
    And I pick a different {'Fill'} color
    And I pick a different {'Outline'} color
    Then the selected bubble {'Fill'} color changed
    And the selected bubble {'Outline'} color changed
