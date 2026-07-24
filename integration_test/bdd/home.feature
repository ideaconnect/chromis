Feature: Home screen and navigation menu
  Home offers the new-project action and an empty state, and the side menu
  reaches the other destinations.

  Scenario: Home shows the new-project action and empty state
    Given the app is freshly launched
    Then the Home screen is shown
    And I see {'New project'}
    And I see {'No projects yet'}
    And no unhandled error occurred

  Scenario: The menu opens All projects
    Given the app is freshly launched
    When I open the menu
    And I tap {'All projects'}
    Then I see {'All projects'}
    And no unhandled error occurred

  Scenario: The menu opens the About sheet
    Given the app is freshly launched
    When I open the menu
    And I tap {'About'}
    Then I see {'The great work we build on'}
    And no unhandled error occurred
