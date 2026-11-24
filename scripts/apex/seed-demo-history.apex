// Demo history for the HR dashboard and the Command Centre (issue #14).
//
// A fresh org only has plans that are still running, so "Average Days to
// Independence" shows 0. This script adds one finished onboarding: Tiago Lopes,
// who joined in June and is now Ana Ferreira's buddy. The plan goes through the
// real lifecycle (Draft -> Ready -> In Progress -> Completed), so every Flow and
// validation rule runs as it would for HR. It also makes sure at least one task
// is overdue, so "Overdue Tasks by Owner" has something to show.
//
// Safe to run more than once: it stops if Tiago's completed plan already exists.
// Run as a user with the Launchpad HR permission set:
//   sf apex run --file scripts/apex/seed-demo-history.apex --target-org launchpad-dev

if (!FeatureManagement.checkPermission('Launchpad_Manage_Plans')) {
    throw new IllegalArgumentException('Run this as a user with the Launchpad HR or Manager permission set.');
}

Map<String, Id> people = new Map<String, Id>();
for (User u : [SELECT Id, Name FROM User WHERE IsActive = TRUE
               AND Name IN ('Tiago Lopes', 'Ricardo Matos', 'Sofia Pereira')]) {
    people.put(u.Name, u.Id);
}
if (people.size() < 3) {
    throw new IllegalArgumentException('Expected active users Tiago Lopes, Ricardo Matos and Sofia Pereira; found ' + people.keySet());
}

List<Onboarding_Plan__c> existing = [
    SELECT Id FROM Onboarding_Plan__c
    WHERE New_Hire__c = :people.get('Tiago Lopes') AND Status__c = 'Completed'
];
if (existing.isEmpty()) {
    List<Project__c> projects = [SELECT Id FROM Project__c WHERE Name = 'Atlântica Internal Portal' LIMIT 1];
    Date startDate = Date.newInstance(2026, 6, 1);

    // 1. Draft, with the Role Brief written and a buddy assigned
    Onboarding_Plan__c plan = new Onboarding_Plan__c(
        New_Hire__c = people.get('Tiago Lopes'),
        Hiring_Manager__c = people.get('Ricardo Matos'),
        Buddy__c = people.get('Sofia Pereira'),
        Project__c = projects.isEmpty() ? null : projects[0].Id,
        Role__c = 'Consultant',
        Department__c = 'Consulting',
        Start_Date__c = startDate,
        Status__c = 'Draft',
        Responsibilities__c = 'Functional consultant on the Meridian Bank account: run requirements workshops, write user stories and support user acceptance testing.',
        Goals_30_Days__c = 'Know the Meridian Bank delivery team and processes; own the backlog for one feature; report time and expenses correctly from week one.',
        Key_Stakeholders__c = 'Ricardo Matos (Delivery Manager), Sofia Pereira (Project Lead), the Meridian Bank product owner'
    );
    insert plan;

    // 2. Ready, then 3. In Progress: the start Flow generates the onboarding tasks
    plan.Status__c = 'Ready';
    update plan;
    plan.Admin_Phase_Complete__c = true;
    plan.Status__c = 'In Progress';
    update plan;

    // 4. Every task done
    List<Onboarding_Task__c> tasks = [SELECT Id FROM Onboarding_Task__c WHERE Onboarding_Plan__c = :plan.Id];
    for (Onboarding_Task__c t : tasks) {
        t.Status__c = 'Completed';
    }
    update tasks;

    // 5. Completed: independent 18 days after starting, under the 21-day target
    plan.Role_Brief_Confirmed__c = true;
    plan.Independence_Date__c = startDate.addDays(18);
    plan.Manager_Assessment__c = 'Working independently on the Meridian Bank backlog after 18 days. Took over requirements workshops in week three.';
    plan.Status__c = 'Completed';
    update plan;
    System.debug('Completed plan for Tiago Lopes with ' + tasks.size() + ' tasks: ' + plan.Id);
} else {
    System.debug('Tiago Lopes already has a completed plan: ' + existing[0].Id);
}

// At least one overdue task, so the overdue report and tile are never empty
Integer overdue = [SELECT COUNT() FROM Onboarding_Task__c WHERE Is_Overdue__c = TRUE];
if (overdue == 0) {
    List<Onboarding_Task__c> open = [
        SELECT Id FROM Onboarding_Task__c
        WHERE Status__c != 'Completed' AND Onboarding_Plan__r.Status__c = 'In Progress'
        ORDER BY Due_Date__c LIMIT 1
    ];
    if (!open.isEmpty()) {
        open[0].Due_Date__c = Date.today().addDays(-3);
        update open;
        overdue = 1;
    }
}
System.debug('Overdue tasks: ' + overdue);
