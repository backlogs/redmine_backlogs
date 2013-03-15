Feature: User interface
  As a user
  I want to use Backlogs via AJAX interface
  So that I can use it without reloading a page

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am logged out
      #And I am a team member of the project
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |

  @javascript
  Scenario: Backlogs page
    Given I am viewing the master backlog

  @javascript
  Scenario: Taskboard page
    Given I am viewing the taskboard for Sprint 001

