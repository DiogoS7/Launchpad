/**
 * Keeps participant shares in step with each plan (BRD SH-01, decision D9).
 * All logic lives in OnboardingPlanSharing.
 */
trigger OnboardingPlanTrigger on Onboarding_Plan__c (after insert, after update) {
    OnboardingPlanSharing.handlePlanChanges(Trigger.new, Trigger.oldMap);
}
