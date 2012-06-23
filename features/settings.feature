Feature: Configuration
  As an administrator
  I want to manage backlogs configuration
  So that it fits my needs

  Background:
    Given the ecookbook project has the backlogs plugin enabled
    Given backlogs is configured

#  Scenario: view the global settings
#    Given I am admin
#      And I am on the homepage
#     When I follow "Administration"
#     When I follow "Plugins"
#     When I follow "Configure"
#     Then I should see "Settings: Redmine Backlogs"

  @javascript
  Scenario: view the project local settings
    Given I am a product owner of the project
      And I am viewing the backlog settings page for project ecookbook
     Then show me a screenshot at /tmp/1.png
     Then I should see "Show stories from subprojects"
      And the "settings[show_stories_from_subprojects]" checkbox should not be checked
     When I check "settings[show_stories_from_subprojects]"
      And I press "Save"
     Then show me a screenshot at /tmp/2.png
     Then I should see "Show stories from subprojects"
     Then show me a screenshot at /tmp/3.png
      And the "settings[show_stories_from_subprojects]" checkbox should be checked

