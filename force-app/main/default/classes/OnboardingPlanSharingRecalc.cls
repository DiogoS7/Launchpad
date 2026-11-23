/**
 * Rebuilds the participant shares on every Onboarding Plan (decision D9).
 *
 * Register it under Setup > Object Manager > Onboarding Plan > Apex Sharing
 * Recalculation so Salesforce can run it when sharing needs rebuilding, or run
 * it on demand with scripts/apex/recalculate-plan-sharing.apex.
 */
public without sharing class OnboardingPlanSharingRecalc implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM Onboarding_Plan__c]);
    }

    public void execute(Database.BatchableContext context, List<Onboarding_Plan__c> scope) {
        OnboardingPlanSharing.recalculate(new Map<Id, Onboarding_Plan__c>(scope).keySet());
    }

    public void finish(Database.BatchableContext context) {
        // Nothing to do: shares are rebuilt batch by batch in execute().
    }
}
