Feature: Go Pro upsell and entitlement
  Non-Pro users are offered the one-time upgrade with restore; Pro users no
  longer see the upsell.

  Scenario: A non-Pro user sees the upgrade and restore
    Given the app is freshly launched
    When I open the menu
    Then I see {'Go Pro · remove ads'}
    When I tap {'Go Pro · remove ads'}
    Then I see {'Remove ads forever'}
    And I see {'Restore purchase'}
    And no unhandled error occurred

  Scenario: A Pro user no longer sees the upsell
    Given the app is launched as Pro
    When I open the menu
    Then I do not see {'Go Pro · remove ads'}
    And no unhandled error occurred
