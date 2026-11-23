// One-off clean-up after moving from v1.0 to v1.1 (decision D9).
// v1.0 shared plans with Flow-created manual shares. Once the participant shares
// have been rebuilt with recalculate-plan-sharing.apex, those manual shares are
// redundant. This deletes manual plan shares that point at a plan participant.
// Run with: sf apex run --file scripts/apex/remove-v1-manual-plan-shares.apex --target-org launchpad-dev
List<Onboarding_Plan__Share> toDelete = new List<Onboarding_Plan__Share>();
for (Onboarding_Plan__Share share : [
    SELECT Id, UserOrGroupId, Parent.New_Hire__c, Parent.Hiring_Manager__c,
           Parent.Buddy__c, Parent.Project__r.Project_Lead__c
    FROM Onboarding_Plan__Share
    WHERE RowCause = 'Manual'
]) {
    Set<Id> participants = new Set<Id>{
        share.Parent.New_Hire__c, share.Parent.Hiring_Manager__c,
        share.Parent.Buddy__c, share.Parent.Project__r?.Project_Lead__c
    };
    if (participants.contains(share.UserOrGroupId)) {
        toDelete.add(share);
    }
}
delete toDelete;
System.debug('Removed ' + toDelete.size() + ' v1.0 manual plan shares.');
