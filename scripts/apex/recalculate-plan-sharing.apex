// Rebuilds the participant shares on every Onboarding Plan (decision D9).
// Run with: sf apex run --file scripts/apex/recalculate-plan-sharing.apex --target-org launchpad-dev
Id jobId = Database.executeBatch(new OnboardingPlanSharingRecalc(), 200);
System.debug('Plan sharing recalculation started: ' + jobId);
