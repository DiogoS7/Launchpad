/**
 * When a project's lead changes, re-shares every plan on that project with the
 * new lead (BRD SH-01, decision D9). All logic lives in OnboardingPlanSharing.
 */
trigger ProjectTrigger on Project__c (after update) {
    OnboardingPlanSharing.handleProjectChanges(Trigger.new, Trigger.oldMap);
}
