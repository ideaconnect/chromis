Feature: Export and share
  The composition can be exported as PNG, JPG or WebP at a chosen resolution
  and saved to the device.

  Background:
    Given the app is launched as Pro
    And I create a new blank project
    And a photo layer is added

  Scenario: Export a PNG at half resolution
    When I tap {'Export'}
    Then I see {'Export & share'}
    When I tap {'PNG'}
    And I tap {'50%'}
    Then the export output summary is shown
    When I save the export to the device
    Then the image was saved to the device
    And no unhandled error occurred

  Scenario: Export a JPG
    When I tap {'Export'}
    And I tap {'JPG'}
    Then the export output summary is shown
    When I save the export to the device
    Then the image was saved to the device
    And no unhandled error occurred

  Scenario: Choose the WebP format
    When I tap {'Export'}
    And I tap {'WebP'}
    Then the export output summary is shown
    And no unhandled error occurred
