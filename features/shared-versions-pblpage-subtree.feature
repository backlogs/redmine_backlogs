Feature: Shared versions in subtree mode
  As a project manager 
  I want to use shared versions
  So that I can manage release over projects

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And sharing is enabled
      And sharing_mode is subtree
      And I have defined the following projects:
        | name   |
        | p1     |
        | p1s1   |
        | p1s1s1 |
        | p1s2   |
        | p2     |

      And the p1 project has the backlogs plugin enabled
      And the p2 project has the backlogs plugin enabled
      And the p1s1 project has the backlogs plugin enabled
      And the p1s1 project is subproject of the p1 project
      And the p1s1s1 project has the backlogs plugin enabled
      And the p1s1s1 project is subproject of the p1s1 project
      And the p1s2 project has the backlogs plugin enabled
      And the p1s2 project is subproject of the p1 project
      And no versions or issues exist
      And I am a product owner of the project
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | sharing     | project_id    |
        | Sp001      | 2010-01-01        | 2010-01-31     | none        | p1            |
        | Sp002      | 2010-01-01        | 2010-01-31     | tree        | p1            |
        | Sp003      | 2010-01-01        | 2010-01-31     | none        | p1s1          |
        | Sp004      | 2010-01-01        | 2010-01-31     | hierarchy   | p1s1          |
        | Sp005      | 2010-01-01        | 2010-01-31     | tree        | p1s1          |
        | Sp006      | 2010-01-01        | 2010-01-31     | descendants | p1s1          |
        | Sp007      | 2010-01-01        | 2010-01-31     | none        | p1s2          |
        | Sp008      | 2010-01-01        | 2010-01-31     | tree        | p1s2          |
        | Sp009      | 2010-01-01        | 2010-01-31     | none        | p1s1s1        |
        | Sp010      | 2010-01-01        | 2010-01-31     | hierarchy   | p1s1s1        |
        | Sp011      | 2010-01-01        | 2010-01-31     | none        | p2            |
        | Sp012      | 2010-01-01        | 2010-01-31     | system      | p2            |
        | Sp013      | 2010-01-01        | 2010-01-31     | none        | p1            |

      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id    |
        | Story 1 | Sp001      | p1            |
        | Story 2 | Sp002      | p1            |
        | Story 3 | Sp003      | p1s1          |
        | Story 4 | Sp004      | p1s1          |
        | Story 5 | Sp005      | p1s1          |
        | Story 6 | Sp006      | p1s1          |
        | Story 7 | Sp007      | p1s2          |
        | Story 8 | Sp008      | p1s2          |
        | Story 9 | Sp009      | p1s1s1        |
        | Story10 | Sp010      | p1s1s1        |
        | Story11 | Sp011      | p2            |
        | Story12 | Sp012      | p2            |
        | Story13 | Sp013      | p1            |

      And I have defined the following stories in the product backlog:
        | subject | project_id    |
        | Story a | ecookbook     |
        | Story b | p1            |
        | Story c | p2            |
        | Story d | p1s1          |
        | Story e | p1s2          |
        | Story f | p1s1s1        |

      And I have defined the following impediments:
        | subject      | sprint     | blocks  |
        | Impediment 1 | Sp001      | Story 1 |
        | Impediment 2 | Sp002      | Story 2 | 
        
  Scenario: View the toplevel backlog page
    Given I have selected the p1 project
      And sharing is not enabled
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 3 sprint backlogs
      And I should see 1 stories in the product backlog

  Scenario: View the toplevel backlog page
    Given I have selected the p1 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 4 stories in the product backlog
      And I should see 7 sprint backlogs
      And I should see the backlog of Sprint Sp001
      And I should see the backlog of Sprint Sp002
      And I should not see the backlog of Sprint Sp003
      And I should see the backlog of Sprint Sp004
      And I should see the backlog of Sprint Sp005
      And I should not see the backlog of Sprint Sp006
      And I should not see the backlog of Sprint Sp007
      And I should see the backlog of Sprint Sp008
      And I should not see the backlog of Sprint Sp009
      And I should see the backlog of Sprint Sp010
      And I should not see the backlog of Sprint Sp011
      And I should not see the backlog of Sprint Sp012
      And I should see the backlog of Sprint Sp013
      And I should see 1 stories in the sprint backlog of Sp001
      And I should see 1 stories in the sprint backlog of Sp002
      And I should see 1 stories in the sprint backlog of Sp013
      And I should see 1 stories in the sprint backlog of Sp004
      And I should see 1 stories in the sprint backlog of Sp005
      And I should see 1 stories in the sprint backlog of Sp008
      And I should see 1 stories in the sprint backlog of Sp010

  Scenario: View the subjproject backlog page in the middle
    Given I have selected the p1s1 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 2 stories in the product backlog
      And I should see 5 sprint backlogs
      And I should not see the backlog of Sprint Sp001
      And I should not see the backlog of Sprint Sp002
      And I should see the backlog of Sprint Sp003
      And I should see the backlog of Sprint Sp004
      And I should see the backlog of Sprint Sp005
      And I should see the backlog of Sprint Sp006
      And I should not see the backlog of Sprint Sp007
      And I should not see the backlog of Sprint Sp008
      And I should not see the backlog of Sprint Sp009
      And I should see the backlog of Sprint Sp010
      And I should not see the backlog of Sprint Sp011
      And I should not see the backlog of Sprint Sp012
      And I should not see the backlog of Sprint Sp013

  Scenario: View the subjproject backlog page at a leaf project
    Given I have selected the p1s1s1 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 1 stories in the product backlog
      And I should see 2 sprint backlogs
      And I should not see the backlog of Sprint Sp001
      And I should not see the backlog of Sprint Sp002
      And I should not see the backlog of Sprint Sp003
      And I should not see the backlog of Sprint Sp004
      And I should not see the backlog of Sprint Sp005
      And I should not see the backlog of Sprint Sp006
      And I should not see the backlog of Sprint Sp007
      And I should not see the backlog of Sprint Sp008
      And I should see the backlog of Sprint Sp009
      And I should see the backlog of Sprint Sp010
      And I should not see the backlog of Sprint Sp011
      And I should not see the backlog of Sprint Sp012
      And I should not see the backlog of Sprint Sp013

  Scenario: View the subjproject backlog page at a middle leaf project
    Given I have selected the p1s2 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 1 stories in the product backlog
      And I should see 2 sprint backlogs
      And I should not see the backlog of Sprint Sp001
      And I should not see the backlog of Sprint Sp002
      And I should not see the backlog of Sprint Sp003
      And I should not see the backlog of Sprint Sp004
      And I should not see the backlog of Sprint Sp005
      And I should not see the backlog of Sprint Sp006
      And I should see the backlog of Sprint Sp007
      And I should see the backlog of Sprint Sp008
      And I should not see the backlog of Sprint Sp009
      And I should not see the backlog of Sprint Sp010
      And I should not see the backlog of Sprint Sp011
      And I should not see the backlog of Sprint Sp012
      And I should not see the backlog of Sprint Sp013

  Scenario: View the subjproject backlog page of a separate project
    Given I have selected the p2 project
      And I am viewing the master backlog
     Then I should see the product backlog
      And I should see 1 stories in the product backlog
      And I should see 2 sprint backlogs
      And I should not see the backlog of Sprint Sp001
      And I should not see the backlog of Sprint Sp002
      And I should not see the backlog of Sprint Sp003
      And I should not see the backlog of Sprint Sp004
      And I should not see the backlog of Sprint Sp005
      And I should not see the backlog of Sprint Sp006
      And I should not see the backlog of Sprint Sp007
      And I should not see the backlog of Sprint Sp008
      And I should not see the backlog of Sprint Sp009
      And I should not see the backlog of Sprint Sp010
      And I should see the backlog of Sprint Sp011
      And I should see the backlog of Sprint Sp012
      And I should not see the backlog of Sprint Sp013

