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
      And sharing is enabled
      And I am viewing the backlog settings page for project ecookbook
     Then I should see "Show stories from subprojects"
      And show_stories_from_subprojects for ecookbook should be true
      And the "settings[show_stories_from_subprojects]" checkbox should be checked
     When I uncheck "settings[show_stories_from_subprojects]"
      And I press "Save"
     Then show_stories_from_subprojects for ecookbook should be false

  Scenario: disable subproject for product backlog
    Given I am a product owner of the project
      And sharing is enabled
      And I have selected the ecookbook project
      And the project selected not to include subprojects in the product backlog
      And I am viewing the backlog settings page for project ecookbook
     Then I should see "Show stories from subprojects"
      And show_stories_from_subprojects for ecookbook should be false
      And the "settings[show_stories_from_subprojects]" checkbox should not be checked
     When I check "settings[show_stories_from_subprojects]"
      And I press "Save"
     Then show_stories_from_subprojects for ecookbook should be true

  Scenario: Change setting Show project in Scrum statistics
    Given I am a product owner of the project
      And I am viewing the backlog settings page for project ecookbook
     Then I should see "Show project in Scrum statistics"
      And show_in_scrum_stats for ecookbook should be true
      And the "settings[show_in_scrum_stats]" checkbox should be checked
     When I uncheck "settings[show_in_scrum_stats]"
      And I press "Save"
     Then show_in_scrum_stats for ecookbook should be false
