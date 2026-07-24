Feature: App installs and launches on the device
  Cold start on real hardware initializes on-device AI, ads, fonts and routing,
  then lands on Home without errors.

  Scenario: Cold start reaches the Home screen
    Given the app is freshly launched
    Then the Home screen is shown
    And no unhandled error occurred
