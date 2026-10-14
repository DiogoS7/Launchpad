import { LightningElement, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';
import { NavigationMixin } from 'lightning/navigation';

const TARGET_DAYS = 21; // BO-01: three weeks to independence
const DAY_MS = 24 * 60 * 60 * 1000;

function toLocalDate(isoDate) {
    if (!isoDate) return null;
    const [y, m, d] = isoDate.split('-').map(Number);
    return new Date(y, m - 1, d);
}

export default class LaunchpadKpis extends NavigationMixin(LightningElement) {
    plans = [];
    openTasks = [];
    loaded = false;
    errors;

    @wire(graphql, {
        query: gql`
            query launchpadKpis {
                uiapi {
                    query {
                        plans: Onboarding_Plan__c(first: 200) {
                            edges {
                                node {
                                    Id
                                    Plan_Title__c { value }
                                    Status__c { value }
                                    Start_Date__c { value }
                                    Buddy__c { value }
                                    Days_To_Independence__c { value }
                                }
                            }
                        }
                        openTasks: Onboarding_Task__c(first: 200, where: { Status__c: { ne: "Completed" } }) {
                            edges {
                                node {
                                    Id
                                    Due_Date__c { value }
                                }
                            }
                        }
                    }
                }
            }
        `
    })
    wiredKpis({ data, errors }) {
        if (data) {
            this.plans = data.uiapi.query.plans.edges.map(({ node }) => ({
                id: node.Id,
                title: node.Plan_Title__c.value,
                status: node.Status__c.value,
                start: node.Start_Date__c.value,
                hasBuddy: !!node.Buddy__c.value,
                days: node.Days_To_Independence__c.value
            }));
            this.openTasks = data.uiapi.query.openTasks.edges.map(({ node }) => ({
                id: node.Id,
                due: node.Due_Date__c.value
            }));
            this.loaded = true;
            this.errors = undefined;
        } else if (errors) {
            this.errors = errors;
        }
    }

    get today() {
        const now = new Date();
        return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }

    get activeCount() {
        return this.plans.filter((p) => p.status === 'In Progress').length;
    }

    get overdueCount() {
        return this.openTasks.filter((t) => t.due && toLocalDate(t.due) < this.today).length;
    }

    get avgDays() {
        const done = this.plans.filter((p) => p.status === 'Completed' && p.days != null);
        if (!done.length) return null;
        return Math.round(done.reduce((sum, p) => sum + p.days, 0) / done.length);
    }

    get launchingSoon() {
        const horizon = new Date(this.today.getTime() + 14 * DAY_MS);
        return this.plans
            .filter((p) => (p.status === 'Draft' || p.status === 'Ready') && p.start)
            .filter((p) => {
                const d = toLocalDate(p.start);
                return d >= this.today && d <= horizon;
            })
            .sort((a, b) => (a.start < b.start ? -1 : 1))
            .map((p) => {
                const daysOut = Math.round((toLocalDate(p.start) - this.today) / DAY_MS);
                const warnings = [];
                if (p.status === 'Draft') warnings.push('Role not ready');
                if (!p.hasBuddy) warnings.push('No buddy');
                return {
                    ...p,
                    countdown: daysOut === 0 ? 'Today' : `T-${daysOut}`,
                    warning: warnings.join(' · '),
                    cls: warnings.length ? 'soon-item soon-item_warn' : 'soon-item'
                };
            });
    }

    get hasLaunchingSoon() {
        return this.launchingSoon.length > 0;
    }

    get tiles() {
        const avg = this.avgDays;
        let avgCls = 'tile';
        let avgNote = 'No completed plans yet';
        if (avg != null) {
            avgCls = avg <= TARGET_DAYS ? 'tile tile_good' : avg <= 35 ? 'tile tile_warn' : 'tile tile_bad';
            avgNote = `Target: ${TARGET_DAYS} days`;
        }
        return [
            { key: 'active', value: this.activeCount, label: 'Plans in orbit', note: 'Status In Progress', cls: 'tile' },
            { key: 'soon', value: this.launchingSoon.length, label: 'Launching soon', note: 'Next 14 days', cls: 'tile' },
            {
                key: 'overdue',
                value: this.overdueCount,
                label: 'Overdue tasks',
                note: 'Across all plans you can see',
                cls: this.overdueCount ? 'tile tile_bad' : 'tile tile_good'
            },
            { key: 'avg', value: avg != null ? avg : '–', label: 'Avg days to independence', note: avgNote, cls: avgCls }
        ];
    }

    openPlan(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }
}
