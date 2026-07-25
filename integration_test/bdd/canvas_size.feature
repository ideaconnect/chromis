Feature: New-project canvas size sheet
  Choosing a preset or a valid custom size creates a project and opens the
  editor.

  # A disabled-Create guard (blank/out-of-range dimensions) is not asserted
  # here: the button is a text label whose tap is simply swallowed when
  # invalid, so "disabled" cannot be observed through find.text. Covered by a
  # widget test instead.

  Scenario: Create from a preset
    Given the app is freshly launched
    When I tap {'New project'}
    And I tap {'Blank canvas'}
    And I tap {'Story'}
    And I tap {'Create'}
    Then the editor is shown
    And no unhandled error occurred

  Scenario: Create with a custom size
    Given the app is freshly launched
    When I tap {'New project'}
    And I tap {'Blank canvas'}
    And I enter a custom canvas size of {1000} by {1600}
    And I tap {'Create'}
    Then the editor is shown
    And no unhandled error occurred
