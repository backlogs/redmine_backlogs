Feature: Sidebar, which requires javascript to show
  As a user
  I want to have useful links in the redmine sidebar
  So that i can quickly navigate to relevant views

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a team member of the project
      And the current date is 2009-11-04
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
      And I have defined the following stories in the product backlog:
        | subject |
        | Story 1 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story A | Sprint 001 |
        | Story B | Sprint 002 |
      And backlogs setting show_burndown_in_sidebar is enabled

  @javascript
  Scenario: Look at the sidebar on the default issues page
     Given I am viewing the issues list
     Then I should see "Sprints" within "#sidebar"
      And I should see "Sprint 001" within "#sidebar"
      And I should see "Sprint 002" within "#sidebar"
      And I should see "eCookbook" within "#sidebar"
      And I should see "Product backlog" within "#sidebar"

  @javascript
  Scenario: Go to the sprint which is current
     Given I am viewing the issues list
     When I follow "Sprint 001"
     Then I should see "Issues" within "#content"
      And I should see "Story A" within "#content"
      And I should see "Task board" within "#sidebar"
      And I should see "Burndown" within "#sidebar"
      And I should see "Sprint cards" within "#sidebar"
      And I should see "Wiki" within "#sidebar"
      And I should see "Impediments" within "#sidebar"
      And I should see the mini-burndown-chart in the sidebar
#TODO: from here click on Task board, Burndown, Impediments

  @javascript
  Scenario: Go to the sprint which is current and then to the task board
     Given I am viewing the issues list
     When I follow "Sprint 001"
      And I follow "Task board"
     Then show me a screenshot at /tmp/1.png
     Then I should see the taskboard

  @javascript
  Scenario: Go to the sprint which is current and then to the burndown
     Given I am viewing the issues list
     When I follow "Sprint 001"
      And I follow "Burndown"
     Then show me a screenshot at /tmp/1.png
     Then I should see the burndown chart of sprint Sprint 001

  @javascript
  Scenario: Go to the product backlog using the sidebar
     Given I am viewing the issues list
     Then I should see "Product backlog" within "#sidebar"
     When I follow "Product backlog"
      And I should see "Issues" within "#content"
      And I should see "Story 1" within "#content"

#  TODO:
#  @javascript
#  Scenario: Open backlog cards using the sidebar
#     Given I am viewing the issues list
#     Then I should see "Product backlog cards" within "#sidebar"
#     When I follow "Product backlog cards"
#      And I should see "Issues" within "#content"
#      And I should see "Story 1" within "#content"

#  @javascript
#  Scenario: Check the url of the javascript snippet which loads the rb sidebar features - when using a relative url not on /
#     Given I am viewing the issues list
