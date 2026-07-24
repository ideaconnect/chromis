Feature: First-run onboarding
  The three intro pages appear once on a fresh install and route to Home when
  skipped or finished.

  Scenario: First launch shows the first intro page
    Given the app is launched for the first time
    Then I see {'Start from a photo'}
    And no unhandled error occurred

  Scenario: Skip jumps straight to Home
    Given the app is launched for the first time
    When I tap {'Skip'}
    Then the Home screen is shown
    And no unhandled error occurred

  Scenario: Advancing through every page reaches Home
    Given the app is launched for the first time
    When I tap {'Next'}
    And I tap {'Next'}
    And I tap {'Get started'}
    Then the Home screen is shown
    And no unhandled error occurred
