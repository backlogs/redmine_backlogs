Feature: Team Member
  As a team member
  I want to drag tasks on a sprint shared across projects
  So that I can update everyone on the status of the sprint

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the subproject1 project has the backlogs plugin enabled
      And sharing is enabled
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
     Then show me a screenshot at /tmp/sc.png
     Then I should see impediment Impediment 4 in the state New
