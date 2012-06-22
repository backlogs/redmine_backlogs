Feature: Configuration
  As an administrator
  I want to manage backlogs configuration
  So that it fits my needs

  Background:
    Given the ecookbook project has the backlogs plugin enabled
    Given backlogs is configured

  Scenario: view the global settings
    Given I am admin
      And I am on the homepage
     When I follow "Administration"
     When I follow "Plugins"
     When I follow "Configure"
     Then I should see "Settings: Redmine Backlogs"

  Scenario: view the project local settings
    Given I am a product owner of the project
      And I am on the project ecookbook page
     When I follow "Settings"
     Then I should see "Backlogs" within "#content .tabs"
     When I follow "Backlogs" within "#content .tabs"
     Then I should see "SETTING"
