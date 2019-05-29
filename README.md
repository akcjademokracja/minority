# Minority

Minority is a gem adding extra functionalities to Identity.
They could hopefully become mainstream one day. Before this happens, though, they stay here.


## Installation

Add to your Gemfile

```
group :minority do
  gem 'minority', git: "https://github.com/akcjademokracja/minority", branch: "master"
end
```

## Contents 

### Bank / wire transfer donation importer

- Shows a page to import CSV we got from the bank with donations made directly to bank account (SWIFT)
- Loading a CSV runs a worker that will try to find a donating member by sender bank accound, email if available, first and last name if not ambiguous, etc.
- Will try to figure out if this donation is a part of regular monthly donation
- Will save the sender bank account no in `members_external_ids` when found
- Will send back by email a CSV with matched transactions, containing `status` column.

files:
- `app/controllers/minority/legacy_donation_import_controller.rb`
- `app/workers/bank_acct/*`


### Aorta 
Aorta is a codename for Freshdesk - Identity integration which is not replaced by identity-freshdesk (https://github.com/akcjademokracja/identity-freshdesk). 
Aorta used RabbitMQ as a pub/sub for events from FD.


### ControlShift campaign categorizer

When CSL petitions are imported as actions/campaigns, it will run workers that
will map CSL petition tags into Identity issues (called Segments in Akcja).

- Plugs into model `CtrlshiftWebhook` model with a concern `Minority::CtrlshiftWebhookCategorize`.
- Schedules workers from `app/workers/controlshift_cathegorize_*` to set categories on campaigns
- Uses `Settings.csl.category_map` from yaml settings file (`app/workers/controlshift_cache_categorizations.rb`)
- Will also create mappings from `category_map` in settings in table `controlshif_issue_link` which is however, not used in identity much (but could be in analytics) 


### Make donation from action worker

Not used any more.

Speakout was sending payu donations only as actions, and Identity has two endpoints: actions api and donations api. This worker would re-create donations record from actions metadata (stored in `member_actions`, `actions_key`, `member_actions_data` et al). 

Now PayU Speakout integration will send data both to actions api and donations api (but there is a new problem of them not being linked in identity)


### Ghostbuster

Not _yet_ active.

This is a worker that should select members to be GDPR-forgotten and anonymize them (called _ghosting_ in identity) 
files: 
- `app/workers/ghostbuster.rb`
- `app/service/gdpr.rb` - this could be unneeded, as identity Member got such methods.

The criteria present there **are not up to date** and this worker should not be run.


### TextSubscription enabler 

Unused. Superseded by `PostConsentMethods` in identity.
files: `app/workers/text_subscription.rb`

### MailingData and TextData additions

Adds `vocative` method to MailingData and TextData so {{vocative}} placeholder can be used in emails, text. Will lookup the Vocative (wołacz) based on first_name in `first_names` table.

Files:
- `app/models/first_name.rb`
- `app/models/minority/mailing_data_vocative.rb`
- `app/models/minority/text_blast_data.rb`


### Custom search filters

Adds custom search filters to identity

Files: `app/models/minority/search/*`


## Development

If you want to work on identity, you can set bundler to use the gem checked out under local path:

`bundle config local.minority /home/marcin/Projects/minority/ ` 

## Contributing

Please follow Identity contributting guidelines.
