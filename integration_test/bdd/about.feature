Feature: About, privacy and licenses
  The menu reaches the in-app privacy summary and the open-source licenses
  screen.

  Scenario: Open the privacy summary
    Given the app is freshly launched
    When I open the menu
    And I tap {'Privacy & Cookies'}
    Then I see {'Full privacy policy'}
    And no unhandled error occurred

  Scenario: Open the licenses screen
    Given the app is freshly launched
    When I open the menu
    And I tap {'Licenses'}
    Then I see {'View full license texts'}
    And no unhandled error occurred
