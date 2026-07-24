Feature: Editor text tool
  A text layer can be given a caption, a font, a size and a colour.

  Background:
    Given the app is freshly launched
    And I create a new blank project

  Scenario: Add text and type a caption
    When I tap the {'Text'} tool
    And I tap {'Add text'}
    Then a text layer is added
    When I enter {'Hello'} as the caption
    Then the selected caption is {'Hello'}

  Scenario: Pick a font
    When I tap the {'Text'} tool
    And I tap {'Add text'}
    And I select the {'Rubik'} font
    Then the selected font is {'Rubik'}

  Scenario: Change size and colour
    When I tap the {'Text'} tool
    And I tap {'Add text'}
    And I move the {'Size'} slider
    Then the selected text size changed
    When I pick a different text color
    Then the selected text color changed
