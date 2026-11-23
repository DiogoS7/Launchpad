/**
 * Tests for OnboardingPlanSharing, OnboardingPlanSharingRecalc and the two
 * triggers (BRD SH-01, decision D9).
 */
@IsTest
private class OnboardingPlanSharingTest {

    private static final String REASON = Schema.Onboarding_Plan__Share.RowCause.Launchpad_Participant__c;

    // Users are created once and found again by their LastName in each test.
    private static final List<String> PEOPLE = new List<String>{
        'NewHire', 'Manager', 'Buddy', 'Lead', 'OtherBuddy', 'OtherLead', 'NewOwner'
    };

    @TestSetup
    static void createUsers() {
        Profile profile = pickProfile(PEOPLE.size());
        PermissionSet employee = [SELECT Id FROM PermissionSet WHERE Name = 'Launchpad_Employee'];
        PermissionSet manager = [SELECT Id FROM PermissionSet WHERE Name = 'Launchpad_Manager'];
        String suffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '');

        List<User> users = new List<User>();
        for (String person : PEOPLE) {
            users.add(new User(
                LastName = person,
                Alias = person.left(8),
                Email = person.toLowerCase() + '@launchpad.test',
                Username = person.toLowerCase() + '.' + suffix + '@launchpad.test',
                ProfileId = profile.Id,
                TimeZoneSidKey = 'Europe/Lisbon',
                LocaleSidKey = 'pt_PT',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8'
            ));
        }
        // Setup objects (users, permission set assignments) are inserted as the running
        // admin so they don't mix with the plan and project records the tests create.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert users;
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
            for (User u : users) {
                Id permissionSetId = u.LastName == 'NewOwner' ? manager.Id : employee.Id;
                assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = permissionSetId));
            }
            insert assignments;
        }
    }

    @IsTest
    static void sharesPlanWithEveryParticipant() {
        Map<String, Id> u = users();
        Project__c project = newProject(u.get('Lead'));

        Test.startTest();
        Onboarding_Plan__c plan = newPlan(u, project.Id);
        Test.stopTest();

        Map<Id, Onboarding_Plan__Share> shares = participantShares(plan.Id);
        Assert.areEqual(4, shares.size(), 'New hire, manager, buddy and project lead should each get a share');
        for (String person : new List<String>{ 'NewHire', 'Manager', 'Buddy', 'Lead' }) {
            Assert.isTrue(shares.containsKey(u.get(person)), person + ' should have a share');
            Assert.areEqual('Edit', shares.get(u.get(person)).AccessLevel, person + ' should have Edit access');
        }
    }

    @IsTest
    static void movesShareWhenBuddyChanges() {
        Map<String, Id> u = users();
        Onboarding_Plan__c plan = newPlan(u, null);

        Test.startTest();
        plan.Buddy__c = u.get('OtherBuddy');
        update plan;
        Test.stopTest();

        Map<Id, Onboarding_Plan__Share> shares = participantShares(plan.Id);
        Assert.isFalse(shares.containsKey(u.get('Buddy')), 'The previous buddy should lose access');
        Assert.isTrue(shares.containsKey(u.get('OtherBuddy')), 'The new buddy should get access');
        Assert.areEqual(3, shares.size(), 'New hire, manager and new buddy should have shares');
    }

    @IsTest
    static void keepsSharesWhenOwnerChanges() {
        Map<String, Id> u = users();
        Onboarding_Plan__c plan = newPlan(u, null);

        Test.startTest();
        plan.OwnerId = u.get('NewOwner');
        update plan;
        Test.stopTest();

        // This is the gap D9 closes: manual shares (v1.0) were deleted on an owner change.
        Assert.areEqual(3, participantShares(plan.Id).size(), 'Participant shares should survive an owner change');
    }

    @IsTest
    static void skipsParticipantWhoOwnsThePlan() {
        Map<String, Id> u = users();
        Onboarding_Plan__c plan = newPlan(u, null);

        Test.startTest();
        plan.OwnerId = u.get('Manager');
        update plan;
        Test.stopTest();

        Map<Id, Onboarding_Plan__Share> shares = participantShares(plan.Id);
        Assert.isFalse(shares.containsKey(u.get('Manager')), 'The owner already has full access and needs no share');
        Assert.areEqual(2, shares.size(), 'New hire and buddy should still have shares');
    }

    @IsTest
    static void followsProjectLeadChange() {
        Map<String, Id> u = users();
        Project__c project = newProject(u.get('Lead'));
        Onboarding_Plan__c plan = newPlan(u, project.Id);

        Test.startTest();
        project.Project_Lead__c = u.get('OtherLead');
        update project;
        Test.stopTest();

        Map<Id, Onboarding_Plan__Share> shares = participantShares(plan.Id);
        Assert.isFalse(shares.containsKey(u.get('Lead')), 'The previous project lead should lose access');
        Assert.isTrue(shares.containsKey(u.get('OtherLead')), 'The new project lead should get access');
    }

    @IsTest
    static void ignoresProjectEditsThatKeepTheLead() {
        Map<String, Id> u = users();
        Project__c project = newProject(u.get('Lead'));
        Onboarding_Plan__c plan = newPlan(u, project.Id);
        Id leadShareId = participantShares(plan.Id).get(u.get('Lead')).Id;

        Test.startTest();
        project.Name = 'Meridian Bank Core Payments Phase 2';
        update project;
        Test.stopTest();

        Assert.areEqual(leadShareId, participantShares(plan.Id).get(u.get('Lead')).Id,
            'Editing a project without changing its lead should not rebuild shares');
    }

    @IsTest
    static void removesProjectLeadWhenProjectIsCleared() {
        Map<String, Id> u = users();
        Project__c project = newProject(u.get('Lead'));
        Onboarding_Plan__c plan = newPlan(u, project.Id);

        Test.startTest();
        plan.Project__c = null;
        update plan;
        Test.stopTest();

        Assert.isFalse(participantShares(plan.Id).containsKey(u.get('Lead')), 'The project lead should lose access');
    }

    @IsTest
    static void ignoresUnrelatedChanges() {
        Map<String, Id> u = users();
        Onboarding_Plan__c plan = newPlan(u, null);
        Map<Id, Onboarding_Plan__Share> before = participantShares(plan.Id);

        Test.startTest();
        plan.Key_Stakeholders__c = 'Delivery lead and client sponsor';
        update plan;
        Test.stopTest();

        Map<Id, Onboarding_Plan__Share> after = participantShares(plan.Id);
        Assert.areEqual(before.size(), after.size(), 'Share count should not change');
        for (Id userId : before.keySet()) {
            Assert.areEqual(before.get(userId).Id, after.get(userId).Id, 'Shares should not be rebuilt for an unrelated change');
        }
    }

    @IsTest
    static void batchRebuildsMissingShares() {
        Map<String, Id> u = users();
        Onboarding_Plan__c plan = newPlan(u, null);
        delete participantShares(plan.Id).values();

        Test.startTest();
        Database.executeBatch(new OnboardingPlanSharingRecalc());
        Test.stopTest();

        Assert.areEqual(3, participantShares(plan.Id).size(), 'The batch should restore every participant share');
    }

    @IsTest
    static void handlesTwoHundredPlansInOneInsert() {
        Map<String, Id> u = users();
        Project__c project = newProject(u.get('Lead'));
        List<Onboarding_Plan__c> plans = new List<Onboarding_Plan__c>();
        for (Integer i = 0; i < 200; i++) {
            plans.add(planFor(u, project.Id));
        }

        Test.startTest();
        insert plans;
        Test.stopTest();

        Integer shareCount = [
            SELECT COUNT() FROM Onboarding_Plan__Share
            WHERE ParentId IN :new Map<Id, Onboarding_Plan__c>(plans).keySet() AND RowCause = :REASON
        ];
        Assert.areEqual(800, shareCount, 'Each of the 200 plans should get 4 participant shares');
    }

    // ---------- helpers ----------

    /** Chooses a profile whose licence has enough free seats for the test users. */
    private static Profile pickProfile(Integer needed) {
        Profile best;
        Integer bestFree = -1;
        for (Profile p : [
            SELECT Id, UserLicense.TotalLicenses, UserLicense.UsedLicenses
            FROM Profile
            WHERE Name IN ('Standard Platform User', 'Standard User')
        ]) {
            Integer free = p.UserLicense.TotalLicenses - p.UserLicense.UsedLicenses;
            if (free > bestFree) {
                best = p;
                bestFree = free;
            }
        }
        return best;
    }

    private static Map<String, Id> users() {
        Map<String, Id> byName = new Map<String, Id>();
        for (User u : [SELECT Id, LastName FROM User WHERE LastName IN :PEOPLE AND Email LIKE '%@launchpad.test']) {
            byName.put(u.LastName, u.Id);
        }
        return byName;
    }

    private static Project__c newProject(Id leadId) {
        Project__c project = new Project__c(Name = 'Meridian Bank Core Payments', Project_Lead__c = leadId);
        insert project;
        return project;
    }

    private static Onboarding_Plan__c planFor(Map<String, Id> u, Id projectId) {
        return new Onboarding_Plan__c(
            New_Hire__c = u.get('NewHire'),
            Hiring_Manager__c = u.get('Manager'),
            Buddy__c = u.get('Buddy'),
            Project__c = projectId,
            Role__c = 'Consultant',
            Department__c = 'Consulting',
            Start_Date__c = Date.today().addDays(30),
            Status__c = 'Draft'
        );
    }

    private static Onboarding_Plan__c newPlan(Map<String, Id> u, Id projectId) {
        Onboarding_Plan__c plan = planFor(u, projectId);
        insert plan;
        return plan;
    }

    private static Map<Id, Onboarding_Plan__Share> participantShares(Id planId) {
        Map<Id, Onboarding_Plan__Share> byUser = new Map<Id, Onboarding_Plan__Share>();
        for (Onboarding_Plan__Share share : [
            SELECT Id, UserOrGroupId, AccessLevel
            FROM Onboarding_Plan__Share
            WHERE ParentId = :planId AND RowCause = :REASON
        ]) {
            byUser.put(share.UserOrGroupId, share);
        }
        return byUser;
    }
}
