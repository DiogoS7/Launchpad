/**
 * Apex managed sharing for Onboarding Plans (BRD SH-01, decision D9).
 *
 * Onboarding plans are Private. Each participant named on a plan (new hire,
 * hiring manager, buddy and the project lead of the plan's project) gets Edit
 * access through a share record with the Launchpad_Participant__c sharing
 * reason. Unlike the manual shares used in v1.0, Apex managed shares are kept
 * when the plan owner changes.
 *
 * Runs without sharing: it must see and maintain every share on the plans it
 * is given, whoever triggered the change. It never reads or changes anything
 * except Onboarding_Plan__Share rows with its own sharing reason.
 */
public without sharing class OnboardingPlanSharing {

    public static final String ACCESS_LEVEL = 'Edit';

    /** Recalculates participant shares for plans whose participants, project or owner changed. */
    public static void handlePlanChanges(List<Onboarding_Plan__c> plans, Map<Id, Onboarding_Plan__c> oldPlans) {
        Set<Id> changed = new Set<Id>();
        for (Onboarding_Plan__c plan : plans) {
            Onboarding_Plan__c old = oldPlans == null ? null : oldPlans.get(plan.Id);
            if (old == null
                    || plan.New_Hire__c != old.New_Hire__c
                    || plan.Hiring_Manager__c != old.Hiring_Manager__c
                    || plan.Buddy__c != old.Buddy__c
                    || plan.Project__c != old.Project__c
                    || plan.OwnerId != old.OwnerId) {
                changed.add(plan.Id);
            }
        }
        recalculate(changed);
    }

    /** Recalculates participant shares for every plan on projects whose project lead changed. */
    public static void handleProjectChanges(List<Project__c> projects, Map<Id, Project__c> oldProjects) {
        Set<Id> changedProjects = new Set<Id>();
        for (Project__c project : projects) {
            if (project.Project_Lead__c != oldProjects.get(project.Id).Project_Lead__c) {
                changedProjects.add(project.Id);
            }
        }
        if (changedProjects.isEmpty()) {
            return;
        }
        Set<Id> planIds = new Map<Id, Onboarding_Plan__c>(
            [SELECT Id FROM Onboarding_Plan__c WHERE Project__c IN :changedProjects]
        ).keySet();
        recalculate(planIds);
    }

    /**
     * Replaces the participant shares on the given plans with one Edit share per
     * active participant. The plan owner already has full access, so is skipped.
     */
    public static void recalculate(Set<Id> planIds) {
        if (planIds == null || planIds.isEmpty()) {
            return;
        }

        List<Onboarding_Plan__c> plans = [
            SELECT Id, OwnerId, New_Hire__c, Hiring_Manager__c, Buddy__c, Project__r.Project_Lead__c
            FROM Onboarding_Plan__c
            WHERE Id IN :planIds
        ];

        Set<Id> participantIds = new Set<Id>();
        for (Onboarding_Plan__c plan : plans) {
            participantIds.addAll(participantsOf(plan));
        }
        Set<Id> activeUserIds = new Map<Id, User>(
            [SELECT Id FROM User WHERE Id IN :participantIds AND IsActive = TRUE]
        ).keySet();

        List<Onboarding_Plan__Share> shares = new List<Onboarding_Plan__Share>();
        for (Onboarding_Plan__c plan : plans) {
            for (Id userId : participantsOf(plan)) {
                if (userId != plan.OwnerId && activeUserIds.contains(userId)) {
                    shares.add(new Onboarding_Plan__Share(
                        ParentId = plan.Id,
                        UserOrGroupId = userId,
                        AccessLevel = ACCESS_LEVEL,
                        RowCause = Schema.Onboarding_Plan__Share.RowCause.Launchpad_Participant__c
                    ));
                }
            }
        }

        delete [
            SELECT Id FROM Onboarding_Plan__Share
            WHERE ParentId IN :planIds
            AND RowCause = :Schema.Onboarding_Plan__Share.RowCause.Launchpad_Participant__c
        ];
        insert shares;
    }

    /** The distinct users named on a plan, ignoring blank lookups. */
    private static Set<Id> participantsOf(Onboarding_Plan__c plan) {
        Set<Id> userIds = new Set<Id>{
            plan.New_Hire__c,
            plan.Hiring_Manager__c,
            plan.Buddy__c,
            plan.Project__r?.Project_Lead__c
        };
        userIds.remove(null);
        return userIds;
    }
}
