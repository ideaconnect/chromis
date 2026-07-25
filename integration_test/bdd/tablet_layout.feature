Feature: Tablet layout
  A tablet gets the extra room; a phone renders exactly what it always did.

  # The screen is resized rather than a tablet being demanded, so this runs on
  # whatever device is attached and still pins both sides of the breakpoint.
  # The resize moves the VIEW, so MediaQuery follows it - which is what the
  # tablet gate reads (see rotateSurface / resizeSurface in _e2e_support).

  Scenario: A tablet in portrait gives the canvas the width
    Given the app is freshly launched
    And I create a new blank project
    When the screen is resized to a {'tablet portrait'}
    Then the editor canvas is wider than {600} px
    When the screen is resized to a {'phone portrait'}
    Then the editor canvas is at most {460} px wide
    And no unhandled error occurred

  Scenario: Home pairs its start cards on a tablet only
    Given the app is freshly launched
    When the screen is resized to a {'tablet landscape'}
    Then the start cards are side by side
    When the screen is resized to a {'phone portrait'}
    Then the start cards are stacked
    And no unhandled error occurred

  Scenario: The tool panel still hugs its content on a tablet
    Given the app is freshly launched
    And I create a new blank project
    When the screen is resized to a {'tablet portrait'}
    Then the tool panel is at most {200} px tall
    And no unhandled error occurred
