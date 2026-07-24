Feature: AI background removal
  The AI Cut tool lifts the subject off its background on device.

  # @device: this scenario runs the real on-device segmentation model
  # (ML Kit / bundled U2-Netp ONNX). It only passes on physical hardware with
  # the models available — skip it on emulators and in CI without a device.

  Background:
    Given the app is launched as Pro
    And I create a new blank project
    And a photo layer is added

  @device
  Scenario: Remove the background from a photo
    When I tap the {'AI Cut'} tool
    And I run background removal
    Then the selected photo has a mask
    And no unhandled error occurred
