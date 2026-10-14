import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { NavigationMixin } from 'lightning/navigation';

import STATUS from '@salesforce/schema/Onboarding_Plan__c.Status__c';
import START_DATE from '@salesforce/schema/Onboarding_Plan__c.Start_Date__c';
import PROGRESS from '@salesforce/schema/Onboarding_Plan__c.Progress__c';
import TOTAL from '@salesforce/schema/Onboarding_Plan__c.Total_Tasks__c';
import COMPLETED from '@salesforce/schema/Onboarding_Plan__c.Completed_Tasks__c';
import DAYS_TO_INDEPENDENCE from '@salesforce/schema/Onboarding_Plan__c.Days_To_Independence__c';
import BUDDY from '@salesforce/schema/Onboarding_Plan__c.Buddy__c';
import MANAGER from '@salesforce/schema/Onboarding_Plan__c.Hiring_Manager__c';

import USER_NAME from '@salesforce/schema/User.Name';
import USER_TITLE from '@salesforce/schema/User.Title';
import USER_PHOTO from '@salesforce/schema/User.SmallPhotoUrl';

const PLAN_FIELDS = [STATUS, START_DATE, PROGRESS, TOTAL, COMPLETED, DAYS_TO_INDEPENDENCE, BUDDY, MANAGER];
const USER_FIELDS = [USER_NAME, USER_TITLE, USER_PHOTO];
const STAGES = ['Draft', 'Ready', 'In Progress', 'Completed'];
const STAGE_LABELS = { Draft: 'Prep', Ready: 'Ready', 'In Progress': 'In orbit', Completed: 'Landed' };
const CATEGORIES = ['Role', 'Tools', 'Buddy', 'Project Handover', 'Admin'];
const DAY_MS = 24 * 60 * 60 * 1000;

function toLocalDate(isoDate) {
    if (!isoDate) return null;
    const [y, m, d] = isoDate.split('-').map(Number);
    return new Date(y, m - 1, d);
}

function todayLocal() {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

function formatDate(isoDate) {
    const d = toLocalDate(isoDate);
    return d ? d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' }) : '';
}

export default class MissionControl extends NavigationMixin(LightningElement) {
    @api recordId;

    plan;
    tasks = [];
    buddy;
    manager;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: PLAN_FIELDS })
    wiredPlan({ data, error }) {
        if (data) {
            this.plan = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Onboarding_Tasks__r',
        fields: [
            'Onboarding_Task__c.Name',
            'Onboarding_Task__c.Status__c',
            'Onboarding_Task__c.Due_Date__c',
            'Onboarding_Task__c.Category__c',
            'Onboarding_Task__c.Is_Overdue__c'
        ],
        optionalFields: ['Onboarding_Task__c.Assigned_To__r.Name'],
        sortBy: ['Onboarding_Task__c.Due_Date__c'],
        pageSize: 100
    })
    wiredTasks({ data }) {
        if (data) {
            this.tasks = data.records.map((r) => ({
                id: r.id,
                name: r.fields.Name.value,
                status: r.fields.Status__c.value,
                due: r.fields.Due_Date__c.value,
                category: r.fields.Category__c.value,
                overdue: r.fields.Is_Overdue__c.value,
                assignee: r.fields.Assigned_To__r?.value?.fields?.Name?.value
            }));
        }
    }

    @wire(getRecord, { recordId: '$buddyId', fields: USER_FIELDS })
    wiredBuddy({ data }) {
        if (data) this.buddy = this.toCrew(data, 'Buddy');
    }

    @wire(getRecord, { recordId: '$managerId', fields: USER_FIELDS })
    wiredManager({ data }) {
        if (data) this.manager = this.toCrew(data, 'Manager');
    }

    toCrew(user, role) {
        const name = getFieldValue(user, USER_NAME);
        return {
            id: user.id,
            role,
            name,
            title: getFieldValue(user, USER_TITLE),
            photo: getFieldValue(user, USER_PHOTO),
            initials: (name || '?').split(' ').map((p) => p[0]).slice(0, 2).join('')
        };
    }

    // ---------- plan values ----------
    get status() {
        return getFieldValue(this.plan, STATUS);
    }
    get buddyId() {
        return this.plan ? getFieldValue(this.plan, BUDDY) : undefined;
    }
    get managerId() {
        return this.plan ? getFieldValue(this.plan, MANAGER) : undefined;
    }
    get progressPct() {
        return Math.round((getFieldValue(this.plan, PROGRESS) || 0) * 100);
    }
    get taskSummary() {
        const total = getFieldValue(this.plan, TOTAL) || 0;
        const done = getFieldValue(this.plan, COMPLETED) || 0;
        return `${done} of ${total} tasks complete`;
    }
    get isLoaded() {
        return !!this.plan;
    }
    get isCancelled() {
        return this.status === 'Cancelled';
    }

    // ---------- countdown ----------
    get countdown() {
        const start = toLocalDate(getFieldValue(this.plan, START_DATE));
        const status = this.status;
        if (status === 'Cancelled') {
            return { big: 'Scrubbed', small: 'This onboarding was cancelled' };
        }
        if (status === 'Completed') {
            const days = getFieldValue(this.plan, DAYS_TO_INDEPENDENCE);
            return { big: 'Landed', small: days != null ? `Independent after ${days} days` : 'Onboarding complete' };
        }
        if (!start) return { big: '–', small: 'No start date yet' };
        const diff = Math.round((start - todayLocal()) / DAY_MS);
        if (diff > 0) return { big: `T-${diff}`, small: diff === 1 ? 'day to launch' : 'days to launch' };
        if (diff === 0) return { big: 'Launch day', small: 'The new hire starts today' };
        return { big: `Day ${-diff + 1}`, small: 'in orbit' };
    }

    // ---------- rocket gauge ----------
    get rocketStyle() {
        const pct = Math.min(100, Math.max(0, this.progressPct));
        return `bottom: calc(${pct}% * 0.78);`;
    }
    get fillStyle() {
        return `height: ${Math.min(100, this.progressPct)}%;`;
    }

    // ---------- stage timeline ----------
    get stages() {
        const current = STAGES.indexOf(this.status);
        return STAGES.map((s, i) => {
            let state = 'todo';
            if (current > i || this.status === 'Completed') state = 'done';
            if (current === i && this.status !== 'Completed') state = 'current';
            return { key: s, label: STAGE_LABELS[s], cls: `stage stage_${state}` };
        });
    }

    // ---------- next task ----------
    get nextTask() {
        const open = this.tasks.find((t) => t.status !== 'Completed');
        if (!open) return null;
        return { ...open, dueLabel: open.due ? `Due ${formatDate(open.due)}` : 'No due date' };
    }
    get allDone() {
        return this.tasks.length > 0 && !this.nextTask;
    }

    // ---------- crew ----------
    get crew() {
        return [this.buddy, this.manager].filter(Boolean);
    }
    get hasCrew() {
        return this.crew.length > 0;
    }

    // ---------- breakdown ----------
    get breakdown() {
        return CATEGORIES.map((c) => {
            const inCat = this.tasks.filter((t) => t.category === c);
            const done = inCat.filter((t) => t.status === 'Completed').length;
            const pct = inCat.length ? Math.round((done / inCat.length) * 100) : 0;
            return { name: c, label: `${done}/${inCat.length}`, total: inCat.length, style: `width: ${pct}%;` };
        }).filter((c) => c.total > 0);
    }
    get hasBreakdown() {
        return this.breakdown.length > 0;
    }

    // ---------- navigation ----------
    openTask() {
        this.navigateTo(this.nextTask.id);
    }
    openUser(event) {
        this.navigateTo(event.currentTarget.dataset.id);
    }
    navigateTo(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }
}
