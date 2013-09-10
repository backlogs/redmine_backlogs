Feature: Release multiview management
  As a product owner
  I want to see progress of multiple releases
  So that I can get an overview of the project

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a product owner of the project
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
      And I have defined the following releases:
        | name     | project    | release_start_date | release_end_date |
        | Rel 1    | ecookbook  | 2010-01-01         | 2010-02-28       |
        | Rel 2    | ecookbook  | 2010-03-01         | 2010-06-01       |
  	| Rel Extra|ecookbook   | 2010-06-01         | 2010-09-01       |
      And I have defined the following release multiviews:
        | name    | project   | releases    |
        | Multi 1 | ecookbook | Rel 1,Rel 2 |
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story 1 | Rel 1   | 2 |
        | Story 2 | Rel 1   | 7 |
        | Story 3 | Rel 2   | 13 |
        | Story 4 | Rel 2   | 20 |
        | Story 5 |         | 40 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1   | 2 |
        | Story B | Sprint 002 | Rel 1   | 3 |
        | Story C | Sprint 003 | Rel 2   | 5 |
        | Story D | Sprint 003 |         | 5 |

  Scenario: Create new release multiview
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "New release multiview"
     Then I should see "New release multiview" within "h2"
     When I select multiple "Rel 1,Rel 2" from "release_multiview_release_ids"
      And I fill in the following:
       | release_multiview_name | A release multiview |
     When I press "Create"
     Then I should see "Successful creation"

  Scenario: Delete a release multiview
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "Multi 1"
     Then I should see "Delete" within ".contextual"
     When I follow "Delete" within ".contextual"
     Then I should see "Release Planning"
     Then I should not see "Multi 1"

  Scenario: Edit a release multiview
    Given I view the release page
     Then I should see "Release Planning"
     When I follow "Multi 1"
     Then I should see "Edit" within ".contextual"
     When I follow "Edit" within ".contextual"
     Then I should see "Release multiview" within "#content"
     When I fill in "release_multiview_name" with "A changed multi"
      And I select multiple "Rel 1,Rel Extra" from "release_multiview_release_ids"
      And I press "Save"
     Then I should see "Successful update"
      And I should see "A changed multi" within "#content"
      And release multiview "A changed multi" should contain "Rel 1,Rel Extra"
