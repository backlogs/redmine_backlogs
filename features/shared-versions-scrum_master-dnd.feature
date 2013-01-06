Feature: Scrum Master impediments
  As a scrum master
  I want to create impediments across projects
  So that I can mitigate issues to ensure the process is improved continuously.

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the subproject1 project has the backlogs plugin enabled
      And sharing is enabled
      And cross_project_issue_relations is enabled
      And I have selected the ecookbook project
      And no versions or issues exist
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | project_id   | sharing     |
        | Sprint 001 | 2010-01-01        | 2010-01-31     | ecookbook    | descendants |
        | Sprint 002 | 2010-02-01        | 2010-02-28     | ecookbook    | descendants |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id   |
        | Story 1 | Sprint 001 | ecookbook    |
        | Story 2 | Sprint 001 | ecookbook    |
        | Story 3 | Sprint 001 | subproject1  |
        | Story 4 | Sprint 002 | ecookbook    |
      And I have defined the following tasks:
        | subject | story  |
        | Task 1  | Story 1 |
        | Task 2  | Story 2 |
        | Task 3  | Story 3 |
        | Task 4  | Story 4 |
      And I have defined the following impediments:
        | subject      | sprint     | blocks  |
        | Impediment 1 | Sprint 001 | Story 1 |
        | Impediment 3 | Sprint 001 | Story 3 | 

 @javascript
  Scenario: Create an impediment using the ajax task editor
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
     When I create an impediment named Impediment 4 which blocks Task 1
     Then impediment Impediment 4 should be created without error
      And I should see impediment Impediment 4 in the state New

  @javascript @optional
  Scenario: Create an impediment using the ajax task editor for a sub-project
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
     When I create an impediment named Impediment 5 which blocks Task 3
     Then impediment Impediment 5 should be created without error
      And I should see impediment Impediment 5 in the state New

  @javascript @optional
  Scenario: Create an impediment using the ajax task editor for a sub-project with 2 blocks and cpir disabled
    Given I am viewing the taskboard for Sprint 001
      And cross_project_issue_relations is disabled
     Then I should see the taskboard
     When I create an impediment named Impediment 6 which blocks Task 3 and Task 4
     Then I should see a msgbox with "Validation failed: Related issue doesn't belong to the same project"

  @javascript @optional
  Scenario: Create an impediment using the ajax task editor for a sub-project with 2 blocks and cpir enabled
    Given I am viewing the taskboard for Sprint 001
     Then I should see the taskboard
     When I create an impediment named Impediment 6 which blocks Task 3 and Task 4
     Then impediment Impediment 6 should be created without error
     Then I should see impediment Impediment 6 in the state New

